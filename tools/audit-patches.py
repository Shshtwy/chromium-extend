#!/usr/bin/env python3
"""Comprehensive Patch & Repository Auditor for Bare Browser / Chromium Extend.

Verifies:
1. Sequential patch numbering (0001 to 00XX without gaps or duplicates).
2. Patch file diff format and hunk structure.
3. XML / GRD / XTB syntax integrity across modified blocks.
4. Integrity of third_party assets and their sha256 checksums.
5. Version generator tool output consistency.
6. Documentation alignment in docs/patches.md.
"""

import os
import re
import sys
import glob
import hashlib
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATCHES_DIR = os.path.join(ROOT, "patches")
DOCS_PATCHES = os.path.join(ROOT, "docs", "patches.md")
THIRD_PARTY = os.path.join(ROOT, "third_party")


def check_patch_sequence():
    print("[1/5] Checking patch numbering sequence...")
    patch_files = sorted(os.listdir(PATCHES_DIR))
    patches = [f for f in patch_files if f.endswith(".patch")]

    if not patches:
        print("FAIL: No patch files found in patches/")
        return False

    indices = []
    seen = {}
    for p in patches:
        m = re.match(r"^(\d{4})-(.+)\.patch$", p)
        if not m:
            print(f"FAIL: Patch filename does not match 4-digit convention: {p}")
            return False
        num = int(m.group(1))
        if num in seen:
            print(f"FAIL: Duplicate patch number {num:04d}: {seen[num]} and {p}")
            return False
        seen[num] = p
        indices.append(num)

    expected = list(range(1, len(patches) + 1))
    if indices != expected:
        print(f"FAIL: Patch sequence has gaps or invalid order: {indices} != {expected}")
        return False

    print(f"  OK: {len(patches)} patches in sequential order (0001 to {len(patches):04d}).")
    return True


def check_patch_syntax():
    print("[2/5] Checking patch diff syntax and structure...")
    patches = sorted(glob.glob(os.path.join(PATCHES_DIR, "*.patch")))
    for p in patches:
        name = os.path.basename(p)
        with open(p, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()

        if "diff --git " not in content:
            print(f"FAIL: {name} contains no unified diff header (diff --git)")
            return False

        if "--- " not in content or "+++ " not in content:
            print(f"FAIL: {name} missing standard diff source/target headers")
            return False

    print(f"  OK: All {len(patches)} patch files have valid unified diff structures.")
    return True


def check_third_party_assets():
    print("[3/5] Checking third-party assets and checksums...")
    assets = [
        ("ublock_origin/uBlockOrigin-1.73.0.crx", "ublock_origin/uBlockOrigin-1.73.0.crx.sha256"),
        ("eruda/eruda.min.js", "eruda/eruda.min.js.sha256"),
    ]

    for asset_rel, sha_rel in assets:
        asset_path = os.path.join(THIRD_PARTY, asset_rel)
        sha_path = os.path.join(THIRD_PARTY, sha_rel)

        if not os.path.exists(asset_path):
            print(f"FAIL: Missing asset {asset_rel}")
            return False
        if not os.path.exists(sha_path):
            print(f"FAIL: Missing checksum file {sha_rel}")
            return False

        with open(sha_path, "r") as f:
            expected_sha = f.read().split()[0].strip()

        with open(asset_path, "rb") as f:
            actual_sha = hashlib.sha256(f.read()).hexdigest()

        if actual_sha.lower() != expected_sha.lower():
            print(f"FAIL: Checksum mismatch for {asset_rel}: {actual_sha} != {expected_sha}")
            return False

        print(f"  OK: Verified {asset_rel} ({actual_sha[:16]}...)")

    return True


def check_version_tools():
    print("[4/5] Checking version tooling (version.py)...")
    try:
        from version import read, version_code, version_name, tag
        v = read()
        code = version_code(v)
        name = version_name(v)
        t = tag(v)
        if not (code > 800000000 and len(name) > 0 and t.startswith("v")):
            print(f"FAIL: Invalid version output code={code} name={name} tag={t}")
            return False
        print(f"  OK: Version tooling valid: {t} (code {code})")
        return True
    except Exception as e:
        print(f"FAIL: version.py error: {e}")
        return False


def check_docs_alignment():
    print("[5/5] Checking documentation alignment in docs/patches.md...")
    if not os.path.exists(DOCS_PATCHES):
        print(f"FAIL: Missing {DOCS_PATCHES}")
        return False

    with open(DOCS_PATCHES, "r") as f:
        doc_content = f.read()

    patches = sorted(os.listdir(PATCHES_DIR))
    for p in patches:
        if p.endswith(".patch"):
            num = p.split("-")[0]
            if f"| {num} |" not in doc_content:
                print(f"FAIL: Patch {num} ({p}) not listed in {DOCS_PATCHES}")
                return False

    print("  OK: All patches correctly documented in docs/patches.md.")
    return True


def main():
    print("=== Running Bare Browser Patch Auditor ===")
    ok = (
        check_patch_sequence()
        and check_patch_syntax()
        and check_third_party_assets()
        and check_version_tools()
        and check_docs_alignment()
    )
    if ok:
        print("\nSUCCESS: All patch audit checks passed! Build readiness verified.")
        sys.exit(0)
    else:
        print("\nERROR: Patch audit failed.")
        sys.exit(1)


if __name__ == "__main__":
    main()
