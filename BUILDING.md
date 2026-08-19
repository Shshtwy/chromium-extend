# Local Chromium Android Desktop builder

This project uses an x86-64 Ubuntu 22.04 container running locally through Docker Desktop.
The Chromium checkout and build output live in the Docker volume `chromium-android-source`.
The Chromium checkout itself is never pushed anywhere — only the patch series in `patches/`,
the build environment, and the docs are tracked. Build output and APKs stay local.

## Matched snapshot

- Snapshot platform: `AndroidDesktop_arm64`
- Snapshot position: `1676236`
- Chromium commit: `945b51156108ba94d62f235a75379772da8ced30`
- Chromium version: `153.0.7999.0`

## Builder commands

```bash
./builder.sh build
./builder.sh start
./builder.sh shell
./builder.sh status
./builder.sh stop
```

Files that need to cross between Linux and macOS go through `exchange/`. Chromium source must
remain in the Linux volume because building from a macOS bind mount is unreliable and slow.

## Bundled extensions

uBlock Origin ships inside the apk, but its `.crx` is kept out of the patch
series: it is a 4MB signed third party binary and base64 in a patch would be
unreviewable. Copy it into the Chromium tree before building:

```
cp third_party/ublock_origin/uBlockOrigin-1.73.0.crx \
   $CHROMIUM_SRC/chrome/browser/resources/bare/ublock_origin.crx
```

Without it the assets target has no input and the build fails at packaging.
See `third_party/ublock_origin/README.md` for provenance, checksum and licence.

## Storage guardrail

Chromium officially requires at least 100 GB free. Check `./builder.sh status` before checkout and
major builds. Stop if macOS free space approaches 30 GB. Do not prune unrelated Docker images,
volumes, or containers; they belong to other local applications.
