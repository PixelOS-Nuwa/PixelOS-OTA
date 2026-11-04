# PixelOS OTA for Xiaomi 13 Pro (nuwa)

This repository serves the nuwa PixelOS Updater using the same per-device
layout as PixelOS-AOSP/official_devices. The canonical feed is
API/updater/nuwa.json, and the changelog is
API/updater/changelogs/nuwa.md. The ROM ZIP is hosted separately on
SourceForge.

See OFFICIAL_LAYOUT.md for the complete official directory comparison and
CertifiedProps adaptation notes.

The root files updates_new.json and nuwa.md remain compatibility paths for
ROMs already installed with the previous Nuwa overlay. The feed generator
updates both JSON feeds by default. Keep the root changelog in sync with the
canonical changelog until those builds are retired.

The feed currently lists the published 2026-11-04 PixelOS 17.0 package. Its
size, SHA-256, and OTA metadata were read from the exact SourceForge ZIP.
Updater only offers it when its timestamp is newer than the installed build.

## Publish an OTA

From the Android source tree root, after uploading the exact ZIP to the
`pixelos-aosp-for-xiaomi-nuwa/PixelOS` directory on SourceForge:

```sh
../pixelos-ota/generate-feed.sh \
  out/target/product/nuwa/PixelOS_nuwa-17.0-YYYYMMDD-HHMM.zip
```

The script defaults to the sibling ../pixelos Android source tree and writes
API/updater/nuwa.json and the legacy updates_new.json in this OTA repository,
regardless of the working directory.
It uses `packages/apps/Updater/tools/pixelos_feed.py` from that source tree;
pass `--android-top /path/to/android` for another checkout. Use `--output`
to preview a feed elsewhere.

The generator validates `pre-device=nuwa`, checks the public HTTP status and
file size, and computes SHA-256 and OTA metadata from the ZIP. Pass `--url`
only if the public ZIP is in another directory. Use the exact uploaded ZIP:
equal size alone does not prove equal content. It omits
`ota_property_files`, so Updater downloads and verifies the full package
before installing it; the xaga feed's streaming path relies on its separate
Range-capable Worker.

Update API/updater/changelogs/nuwa.md with release notes and keep the legacy
nuwa.md in sync during the transition. Inspect both feed files, then commit
and push the seventeen branch. A ROM using the updated UpdaterOverlayNuwa
requests these URLs:

```text
https://raw.githubusercontent.com/PixelOS-Nuwa/PixelOS-OTA/refs/heads/seventeen/API/updater/nuwa.json
https://raw.githubusercontent.com/PixelOS-Nuwa/PixelOS-OTA/refs/heads/seventeen/API/updater/changelogs/nuwa.md
```

Older installed builds continue using the previous updates_new.json and
nuwa.md URLs until upgraded.
Publish this repository before flashing a ROM that uses the updated overlay.
Check that both new raw GitHub URLs return HTTP 200; until these files are
committed and pushed, the new ROM will receive HTTP 404 for update checks.

The update's `datetime` must exceed the installed ROM's `ro.build.date.utc`.
After pushing, verify the public JSON is accessible before checking on the
phone.
