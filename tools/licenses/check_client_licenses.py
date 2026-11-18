#!/usr/bin/env python3
"""Client (Flutter/Dart) licence gate.  Usage (from repo root, after `flutter pub get`):

    python3 tools/licenses/check_client_licenses.py [--lock pubspec.lock] [--policy tools/licenses/client-policy.json]
                                                    [--out build/license-report/client] [--pub-cache DIR]

Detection of each package's licence is delegated to `very_good packages check licenses` (CSV mode).
This wrapper adds what that tool does NOT do (verified on very_good_cli 1.7.0, see docs):
  * it silently skips `path:` / `git:` dependencies  -> we block them unless excepted
  * it has no notion of review/unknown tiers         -> we implement allowed/review/forbidden/unknown
  * it cannot see MPL-2.0 "Exhibit B" notices        -> we grep package sources
  * it cannot see what a plugin embeds (e.g. Unity)  -> deny_packages list
Exit code 1 if anything blocks (forbidden, unknown, unapproved review, denied package, bad source, Exhibit B).
"""
import argparse, csv, io, os, re, shutil, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _policy import Policy, Finding, evaluate, report_and_exit, scan_dir_for_exhibit_b  # noqa: E402


def parse_lock(path):
    """Minimal pubspec.lock parser (stdlib only). Returns {name: {version, source, dependency}}."""
    pkgs, cur, in_pkgs = {}, None, False
    for line in open(path, encoding="utf-8"):
        if line.startswith("packages:"):
            in_pkgs = True
            continue
        if line.startswith("sdks:"):
            in_pkgs = False
        if not in_pkgs:
            continue
        m = re.match(r"^  ([A-Za-z0-9_\-\.]+):\s*$", line)
        if m:
            cur = m.group(1)
            pkgs[cur] = {}
            continue
        m = re.match(r'^    (dependency|source|version): "?([^"\n]+)"?\s*$', line)
        if m and cur:
            pkgs[cur][m.group(1)] = m.group(2)
    return pkgs


def pub_cache_dir(arg):
    if arg:
        return arg
    return os.environ.get("PUB_CACHE") or os.path.join(os.path.expanduser("~"), ".pub-cache")


def run_vgv(types):
    exe = shutil.which("very_good")
    if not exe:
        sys.exit("very_good not found: run `dart pub global activate very_good_cli <pinned-version>` first")
    cmd = [exe, "packages", "check", "licenses", "--reporter=csv", "--ignore-retrieval-failures"]
    for t in types:
        cmd += ["--dependency-type", t]
    out = subprocess.run(cmd, capture_output=True, text=True)
    rows = {}
    for line in (out.stdout + "\n" + out.stderr).replace("\r", "\n").splitlines():
        if re.match(r"^[A-Za-z0-9_\.]+,[^,\s][^,]*$", line.strip()):
            name, lic = line.strip().split(",", 1)
            rows.setdefault(name, []).append(lic.strip())
    return rows, out.returncode


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lock", default="pubspec.lock")
    ap.add_argument("--policy", default="tools/licenses/client-policy.json")
    ap.add_argument("--out", default="build/license-report/client")
    ap.add_argument("--pub-cache")
    ap.add_argument("--exclude-dev", action="store_true", help="skip `direct dev` deps. Off by default: in a pub workspace the lock marks members' deps as 'transitive', so dev/prod cannot be told apart reliably; gating everything is the conservative choice")
    a = ap.parse_args()

    pol = Policy.load(a.policy)
    lock = parse_lock(a.lock)
    if not lock:
        sys.exit(f"no packages parsed from {a.lock}")
    rows, rc = run_vgv(["direct-main", "direct-dev", "transitive", "direct-overridden"])
    findings = []
    cache = pub_cache_dir(a.pub_cache)

    for name, meta in sorted(lock.items()):
        ver, src = meta.get("version", "?"), meta.get("source", "?")
        if meta.get("dependency") == "direct dev" and a.exclude_dev:
            continue          # build/test tooling, not distributed in the app
        if src == "sdk":      # flutter SDK packages: covered by Flutter's own BSD-3-Clause + engine NOTICES, see docs
            continue
        if name in pol.raw.get("deny_packages", {}):
            findings.append(Finding(name, ver, "-", "blocked", "deny_packages: " + pol.raw["deny_packages"][name]))
            continue
        if src not in pol.raw.get("allowed_sources", ["hosted"]):
            ex = pol.find_exception(name, "*")
            if ex:
                findings.append(Finding(name, ver, f"source={src}", "allowed", "non-hosted source approved by exception", ex["approved_by"]))
            else:
                findings.append(Finding(name, ver, f"source={src}", "blocked",
                                        "path/git dependency is invisible to the scanner: needs manual licence review + exception"))
            continue
        lics = rows.get(name)
        if not lics:
            findings.append(Finding(name, ver, "Unknown", "unknown", "licence could not be retrieved/detected"))
            continue
        # several licences in one LICENSE file => all of them apply (AND)
        findings.append(evaluate(pol, name, ver, " AND ".join(sorted(set(lics)))))

    # MPL-2.0 Exhibit B: scan sources of every hosted package that is MPL-2.0 (cheap) OR unknown
    hosted_dir = os.path.join(cache, "hosted", "pub.dev")
    for f in list(findings):
        if "MPL-2.0" in f.license and os.path.isdir(hosted_dir):
            d = os.path.join(hosted_dir, f"{f.package}-{f.version}")
            hits = scan_dir_for_exhibit_b(d) if os.path.isdir(d) else []
            if hits:
                f.level, f.reason = "forbidden", "MPL-2.0 Exhibit B ('Incompatible With Secondary Licenses') found in " + os.path.relpath(hits[0], d)
            elif not os.path.isdir(d):
                f.level, f.reason = "unknown", "package source not found in pub cache; cannot check Exhibit B"

    sys.exit(report_and_exit(findings, a.out, "Client licence scan"))


if __name__ == "__main__":
    main()
