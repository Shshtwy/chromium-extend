#!/usr/bin/env python3
"""Hashes an APK's contents, ignoring the signature.

Bare is signed with a private key, so nobody else can reproduce the signed file
byte for byte: they cannot produce the signature. Everything the build actually
produced is still reproducible, and this is what lets you check that. It hashes
every entry except the signature block, so two APKs built from the same source
agree here whoever signed them.

    tools/apk-content-hash.py Bare-1.0.0-alpha.1.apk out/Optimized/apks/ChromePublic.apk

Matching output means the two builds are identical in everything but who signed
them. To check who signed one, use apksigner:

    apksigner verify --print-certs Bare-1.0.0-alpha.1.apk
"""

import hashlib
import sys
import zipfile


def content_hash(path):
    h = hashlib.sha256()
    with zipfile.ZipFile(path) as z:
        for name in sorted(z.namelist()):
            # The v1 signature lives in META-INF. The v2/v3 blocks live outside
            # the zip structure entirely, between the entries and the central
            # directory, so reading entries never sees them.
            if name.startswith("META-INF/"):
                continue
            h.update(name.encode("utf-8"))
            h.update(b"\0")
            h.update(z.read(name))
    return h.hexdigest()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    results = [(p, content_hash(p)) for p in sys.argv[1:]]
    for path, digest in results:
        print("%s  %s" % (digest, path))
    if len(results) > 1:
        same = len({d for _, d in results}) == 1
        print()
        print("identical contents" if same else "CONTENTS DIFFER")
        sys.exit(0 if same else 1)
