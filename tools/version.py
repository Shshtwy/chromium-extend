#!/usr/bin/env python3
"""Bare's version numbers, derived from the VERSION file at the repo root.

Chromium derives its Android versionCode from its own build number, so every
Bare release built on the same Chromium would otherwise carry an identical one.
Android only compares versionCode when deciding whether an APK may replace
another, so identical numbers mean no update can ever be recognised. Bare
therefore owns its own.

The base sits above the highest number the old Chromium Extend line ever
shipped (799900074), because Android refuses a downgrade and anything lower
would be unable to replace an existing install.
"""

import os
import sys

BASE = 800000000
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read():
    v = {}
    with open(os.path.join(ROOT, "VERSION")) as f:
        for line in f:
            line = line.split("#", 1)[0].strip()
            if "=" in line:
                k, _, val = line.partition("=")
                v[k.strip()] = val.strip()
    return v


def version_code(v):
    code = (BASE
            + int(v["MAJOR"]) * 1000000
            + int(v["MINOR"]) * 10000
            + int(v["PATCH"]) * 100
            + int(v["BUILD"]))
    assert code < 2100000000, "versionCode past Android's ceiling"
    return code


def version_name(v):
    name = "%s.%s.%s" % (v["MAJOR"], v["MINOR"], v["PATCH"])
    if v["CHANNEL"] != "stable":
        name += "-%s.%s" % (v["CHANNEL"], v["CHANNEL_NUM"])
    return name


def tag(v):
    return "v" + version_name(v)


if __name__ == "__main__":
    v = read()
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what == "code":
        print(version_code(v))
    elif what == "name":
        print(version_name(v))
    elif what == "tag":
        print(tag(v))
    elif what == "gn":
        # Paste into args.gn. Both are plain declare_args in
        # build/config/android/config.gni, so no patch is needed to use them.
        print('android_override_version_code = "%d"' % version_code(v))
        print('android_override_version_name = "%s"' % version_name(v))
    else:
        print("versionName %s" % version_name(v))
        print("versionCode %d" % version_code(v))
        print("tag         %s" % tag(v))
