#!/usr/bin/env python3
"""Heuristic hint scanner: does an image carry generator metadata (PNG text chunks such as `parameters`/`prompt`,
a C2PA/JUMBF manifest, or a Software tag)?  Stdlib only.

    python3 tools/licenses/scan_asset_metadata.py assets/

IMPORTANT: this only finds *positive hints*. Metadata is routinely stripped, so "no hint" proves NOTHING about whether
an image is AI-generated. Provenance must come from the author's signed statement (docs/compliance/).
Exit code is always 0 (informational).
"""
import os, struct, sys, zlib

KEYS = {b"parameters", b"prompt", b"workflow", b"software", b"comment", b"description", b"generator", b"model",
        b"sd-metadata", b"invokeai_metadata", b"dream", b"negative prompt"}


def png_chunks(data):
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return
    i = 8
    while i + 8 <= len(data):
        ln, typ = struct.unpack(">I4s", data[i:i + 8])
        yield typ, data[i + 8:i + 8 + ln]
        i += 12 + ln


def scan(path):
    data = open(path, "rb").read()
    hints = []
    if b"c2pa" in data or b"jumb" in data:
        hints.append("C2PA/JUMBF marker present")
    for typ, body in png_chunks(data):
        if typ in (b"tEXt", b"iTXt", b"zTXt"):
            key = body.split(b"\x00", 1)[0].lower()
            if key in KEYS:
                val = body.split(b"\x00", 1)[1] if b"\x00" in body else b""
                if typ == b"zTXt":
                    try:
                        val = zlib.decompress(val[1:])
                    except zlib.error:
                        pass
                hints.append(f"PNG {typ.decode()} key={key.decode()!r}: {val[:80]!r}")
    for marker in (b"Stable Diffusion", b"Midjourney", b"DALL", b"Firefly", b"ComfyUI", b"InvokeAI"):
        if marker in data:
            hints.append(f"contains text '{marker.decode()}'")
    return hints


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "assets"
    n = 0
    for dp, _, fns in os.walk(root):
        for fn in sorted(fns):
            if fn.lower().endswith((".png", ".jpg", ".jpeg", ".webp", ".gif")):
                n += 1
                h = scan(os.path.join(dp, fn))
                print(f"{'HINT ' if h else 'none '} {os.path.join(dp, fn)}")
                for x in h:
                    print("      -", x)
    print(f"{n} image files scanned. 'none' is NOT evidence of human or script provenance.")


if __name__ == "__main__":
    main()
