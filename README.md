# PixelOS OTA for Xiaomi 13 Pro (nuwa)

This repository prepares the nuwa PixelOS Updater's array-format
`updates_new.json` feed and `nuwa.md` changelog. ROM ZIPs are hosted separately
on SourceForge.

## Generate an OTA feed

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
the feed and changelog. The update's `datetime` must exceed the installed
ROM's `ro.build.date.utc`.
