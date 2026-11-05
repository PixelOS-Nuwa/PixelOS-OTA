# PixelOS OTA for Xiaomi 13 Pro (nuwa)

This repository serves the nuwa PixelOS Updater using the same per-device
layout as PixelOS-AOSP/official_devices. The canonical feed is
API/updater/nuwa.json, and the changelog is
API/updater/changelogs/nuwa.md. The ROM ZIP is hosted separately on
SourceForge.

See OFFICIAL_LAYOUT.md for the complete official directory comparison and
CertifiedProps adaptation notes.

The feed lists the current nuwa build and may pair it with one source-specific
incremental OTA. Updater checks whether that payload applies to the installed
build and keeps the full package available as a fallback. The public changelog
contains only the current build; the local-only history is the ignored root
file `nuwa.md`.

## Publish an OTA

From the Android source tree root, after uploading the exact ZIP to the
`aosp-nuwa/PixelOS` directory on SourceForge:

```sh
../pixelos-ota/generate-feed.sh \
  out/target/product/nuwa/PixelOS_nuwa-17.0-YYYYMMDD-HHMM.zip
```

The script defaults to the sibling ../pixelos Android source tree and writes
API/updater/nuwa.json in this OTA repository, regardless of the working directory.
It uses `packages/apps/Updater/tools/pixelos_feed.py` from that source tree;
pass `--android-top /path/to/android` for another checkout. Use `--output`
to preview a feed elsewhere.

The generator validates `pre-device=nuwa`, checks the public HTTP status and
file size, and computes SHA-256 and OTA metadata from the ZIP. Pass `--url`
only if the public ZIP is in another directory. Use the exact uploaded ZIP:
equal size alone does not prove equal content. For the full package it omits
`ota_property_files` because the SourceForge download endpoint is not relied
on for range streaming.

## Build and publish an incremental OTA

Retain the target-files ZIP from every release that may be an upgrade source.
The source and target archives must be for nuwa, use the same release signing
keys, and match the builds installed on devices. Build the target archive with
the target ROM configuration:

```sh
source build/envsetup.sh
lunch custom_nuwa-cp2a-userdebug
m target-files-package otatools
```

Create a source-specific A/B OTA from the old and new target-files packages:

```sh
out/host/linux-x86/bin/ota_from_target_files \
  -i /path/to/old-nuwa-target_files.zip \
  /path/to/new-nuwa-target_files.zip \
  out/target/product/nuwa/PixelOS_nuwa-incremental-OLD-to-NEW.zip
```

For release builds, sign both target-files packages with the same release
keys first, and pass the corresponding OTA package key with `-k`. Do not use
userdebug test-key target-files to generate a delta for a release-key ROM.
Keep each source target-files archive; an installed full OTA ZIP is not a
replacement for it.

Upload the incremental ZIP to the SourceForge `PixelOS` directory, then
regenerate the feed using both exact local artifacts:

```sh
../pixelos-ota/generate-feed.sh \
  out/target/product/nuwa/PixelOS_nuwa-17.0-YYYYMMDD-HHMM.zip \
  --incremental out/target/product/nuwa/PixelOS_nuwa-incremental-OLD-to-NEW.zip
```

The script checks that the full package and delta are publicly reachable and
match their local sizes. It also requires the incremental URL to return HTTP
206 for a byte-range request, because Updater reads and verifies the payload
metadata before offering the delta. Since this request may follow SourceForge
redirects, the redirect endpoint must preserve the Range header and return one
byte with the correct `Content-Range`. The feed validator checks that the delta's
`pre-build` is present, its `post-build` and timestamp match the full package,
its A/B payload ranges are valid, and it is smaller than the full OTA. If any
check fails, the published feed is not replaced. Keep the full OTA entry: it
is the fallback when a delta does not apply or installation fails.

Updater currently accepts one incremental per full release. The delta is
source-specific; Android UpdateEngine verifies applicability against the
installed partitions. Begin by publishing a delta from the immediately prior
release and retain the full OTA for every device as the recovery path.

Keep API/updater/changelogs/nuwa.md limited to the current release and store
historical notes in a local-only file. Inspect the feed, then commit and push
the seventeen branch. A ROM using UpdaterOverlayNuwa
requests these URLs:

```text
https://raw.githubusercontent.com/PixelOS-Nuwa/PixelOS-OTA/refs/heads/seventeen/API/updater/nuwa.json
https://raw.githubusercontent.com/PixelOS-Nuwa/PixelOS-OTA/refs/heads/seventeen/API/updater/changelogs/nuwa.md
```

Publish this repository before flashing a ROM that uses the updated overlay.
Check that both new raw GitHub URLs return HTTP 200; until these files are
committed and pushed, the new ROM will receive HTTP 404 for update checks.

The update's `datetime` must exceed the installed ROM's `ro.build.date.utc`.
After pushing, verify the public JSON is accessible before checking on the
phone.
