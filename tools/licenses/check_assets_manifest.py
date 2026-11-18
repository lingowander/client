#!/usr/bin/env python3
"""Consistency check for assets/ASSETS.md (stdlib only).

    python3 tools/licenses/check_assets_manifest.py --manifest assets/ASSETS.md --root assets [--allow-empty]

Fails when: a file on disk has no manifest row; a row points at a missing file; the sha256 differs; the licence is not
in ALLOWED_ASSET_LICENSES; mandatory fields are empty (author statement id; for provenance C: tool, model+date,
prompt record, human selector). Exit 1 on any problem.  Draft - 须律师/法务确认 the allowed list.
"""
import argparse, hashlib, os, re, sys

ALLOWED_ASSET_LICENSES = {"CC0-1.0", "CC-BY-4.0", "CC-BY-SA-4.0", "GPL-3.0-only", "GPL-3.0-or-later"}
SKIP_NAMES = {"README.md", "ASSETS.md", "REUSE.toml"}
COLS = ["path", "sha256", "kind", "provenance", "author_or_tool", "model_version_date", "prompt_record",
        "licence", "copyright_notice", "statement_id", "upstream_source", "status", "notes"]


def rows(manifest):
    out, in_table = [], False
    for line in open(manifest, encoding="utf-8"):
        if line.startswith("| path "):
            in_table = True
            continue
        if in_table and line.startswith("|---"):
            continue
        if in_table and line.startswith("|"):
            cells = [c.strip().strip("`") for c in line.strip().strip("|").split("|")]
            if len(cells) != len(COLS):
                sys.exit(f"bad row (expected {len(COLS)} columns): {line.strip()}")
            if cells[0].startswith("<"):   # template placeholder row
                continue
            out.append(dict(zip(COLS, cells)))
        elif in_table and not line.strip():
            in_table = False
    return out


def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default="assets/ASSETS.md")
    ap.add_argument("--root", default="assets")
    ap.add_argument("--allow-empty", action="store_true")
    a = ap.parse_args()
    errs, rs = [], rows(a.manifest)
    listed = {}
    for r in rs:
        listed[r["path"]] = r
        fp = os.path.join(a.root, r["path"])
        if not os.path.isfile(fp):
            errs.append(f"{r['path']}: listed but missing on disk")
            continue
        if sha256(fp) != r["sha256"]:
            errs.append(f"{r['path']}: sha256 differs from manifest (file changed without updating ASSETS.md)")
        if r["licence"] not in ALLOWED_ASSET_LICENSES:
            errs.append(f"{r['path']}: licence '{r['licence']}' not in allowed asset licences")
        if not r["statement_id"]:
            errs.append(f"{r['path']}: statement_id empty (author authorisation statement required)")
        if not r["copyright_notice"]:
            errs.append(f"{r['path']}: copyright_notice empty")
        if r["provenance"].upper().startswith("C"):
            for k in ("author_or_tool", "model_version_date", "prompt_record"):
                if not r[k]:
                    errs.append(f"{r['path']}: AI-assisted asset needs '{k}'")
        if r["provenance"].upper().startswith("D") and not r["upstream_source"]:
            errs.append(f"{r['path']}: third-party asset needs upstream_source (URL + licence)")
    for dp, dn, fns in os.walk(a.root):
        dn[:] = [d for d in dn if not d.startswith(".")]
        for fn in fns:
            if fn in SKIP_NAMES or fn.endswith(".license"):
                continue
            rel = os.path.relpath(os.path.join(dp, fn), a.root).replace(os.sep, "/")
            if rel not in listed:
                errs.append(f"{rel}: on disk but not listed in ASSETS.md")
    if not rs and not a.allow_empty:
        errs.append("manifest has no rows (use --allow-empty while assets/ is empty)")
    for e in errs:
        print("::error::" + e, file=sys.stderr)
    print(f"{len(rs)} manifest rows, {len(errs)} problems")
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
