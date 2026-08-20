# Reproducibility

What has been measured about rebuilding Bare, and what has not.

## The measurement

The same tree was built two ways:

| Build | How | SHA-256 |
| --- | --- | --- |
| `out/PixelFold` | incremental, with a day of history including an applied-then-reverted patch | `19577669…fb492d48` |
| `out/Verify` | clean, from nothing, in a differently-named directory | `19577669…fb492d48` |

Identical hashes, identical size, from a 6h15m clobber build against an incremental one. The
differing directory name matters: a build path leaking into a binary is the most common cause of
irreproducibility, and Chromium's [deterministic build
support](https://chromium.googlesource.com/chromium/src/+/main/docs/deterministic_builds.md)
holds here. Zip timestamps, the other usual cause, are already handled upstream: every entry is
stamped `2001-01-01 00:00` rather than build time.

That measurement was taken while builds were still signed with Chromium's checked-in debug key,
which every build shares, so the APKs matched whole. They no longer do, and should not. Compare
with `tools/apk-content-hash.py`, which skips the signature block.

## What this does and does not prove

**Proven:** the build is deterministic in this container: directory names, build history, and
clobber-versus-incremental do not change the output.

**Not yet proven:** that a rebuild on *different* hardware, or in a container built at a
different time, produces the same bytes. `docker/Dockerfile` starts from `ubuntu:22.04` and
installs packages with `apt-get`, so the image drifts as upstream packages change. Chromium
ships a hermetic toolchain through `DEPS`, so the host package set most likely does not affect
the output, but that link is untested here, and a reproducibility claim is the wrong place for
"most likely". If you rebuild on your own machine and get a different hash, please open an issue;
that is the missing measurement.

## Release hashes

Each release publishes the SHA-256 of its APK. That confirms the file you fetched is the file
that was uploaded, and nothing more: it is self-attested, so on its own it proves nothing about
provenance. The rebuild comparison is what does that, and the signing certificate is what ties a
build to Bare.

| Release | Line | Signed with | SHA-256 |
| --- | --- | --- | --- |
| v1.2 | Chromium Extend | Chromium debug key | `8fe506d5e89da5a8c4c8feff0e74d8151334ee820eccf1223ca4a044ddfb6d33` |
| v1.4 | Chromium Extend | Chromium debug key | `e70364b58f215c3a390fe92622d844112462ea21a604da15e77ec40f3e082105` |

The Chromium Extend releases are left published as the line Bare grew out of. Their hashes are
still good for checking a download, but their signatures mean nothing: the key is public.
