# uBlock Origin

Bare ships uBlock Origin so that content blocking works the moment the browser
is installed. It is pre-installed but not pinned, and it can be disabled or
removed like any other extension.

## What this is

`uBlockOrigin-1.73.0.crx` is the unmodified extension as published by its
author, downloaded from the Chrome Web Store. Nothing in it has been changed,
repackaged or re-signed, so it keeps its original extension ID
(`cjpalhdlnbpafiamejdnhcphjbkeiagm`) and its original signature.

    version   1.73.0
    id        cjpalhdlnbpafiamejdnhcphjbkeiagm
    source    Chrome Web Store
    sha256    see uBlockOrigin-1.73.0.crx.sha256

## Licence

uBlock Origin is copyright Raymond Hill and contributors, and is licensed under
the **GNU General Public License v3.0**. The full licence text ships inside the
extension as `LICENSE.txt`.

Bare itself is BSD licensed. Distributing the two together is mere aggregation:
uBlock Origin remains under the GPL and Bare's licence is unaffected. Because
the extension is redistributed unmodified, the corresponding source is the
upstream release, available at:

    https://github.com/gorhill/uBlock/releases/tag/1.73.0

## Updating

This copy is frozen at the version above. Filter lists still update on their
own, so blocking stays current between releases, but the extension code only
moves when this file is replaced and Bare is rebuilt.

Replace the `.crx`, refresh the `.sha256`, and update the version referenced by
the loader patch.
