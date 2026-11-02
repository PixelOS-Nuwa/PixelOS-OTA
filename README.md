# PixelOS OTA for Xiaomi 13 Pro (nuwa)

This repository serves the nuwa PixelOS Updater. `updates_new.json` is 
the current array-format feed and `nuwa.md` is the changelog. 
The ROM ZIP is hosted separately on SourceForge.

The feed currently lists the published 2026-10-21 PixelOS 17.0 package. Its
size, SHA-256, and OTA metadata were read from the exact SourceForge ZIP.
Updater only offers it when its timestamp is newer than the installed build.
A newer ROM containing `UpdaterOverlayNuwa` therefore needs a newer published
OTA package before an on-device upgrade will appear.

## Publish an OTA

From the Android source tree root, after uploading the exact ZIP to the
`pixelos-aosp-for-xiaomi-nuwa/PixelOS` directory on SourceForge:

```sh
../pixelos-ota/generate-feed.sh \
  out/target/product/nuwa/PixelOS_nuwa-17.0-YYYYMMDD-HHMM.zip
```

The script defaults to the sibling `../pixelos` Android source tree and writes
`updates_new.json` in this OTA repository, regardless of the working directory.
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

Update `nuwa.md` with release notes, inspect the JSON, then commit and push
the `seventeen` branch. A ROM containing `UpdaterOverlayNuwa` requests these URLs:

```text
https://raw.githubusercontent.com/PixelOS-Nuwa/PixelOS-OTA/refs/heads/seventeen/updates_new.json
https://raw.githubusercontent.com/PixelOS-Nuwa/PixelOS-OTA/refs/heads/seventeen/nuwa.md
```

The update's `datetime` must exceed the installed ROM's `ro.build.date.utc`.
After pushing, verify the public JSON is accessible before checking on the
phone.
