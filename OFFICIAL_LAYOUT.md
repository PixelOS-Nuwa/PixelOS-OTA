# PixelOS official_devices layout audit

Compared with PixelOS-AOSP/official_devices branch seventeen at
a78a79c3a77ef5d195e5cd925dd5109f4d048645 (392 tracked files).

| Official path | Files | Nuwa treatment |
| --- | ---: | --- |
| .github/ISSUE_TEMPLATE, scripts, workflows | 6 | Website and multi-device automation; do not copy. |
| .gitignore | 1 | Use this repository's own ignore rules if needed. |
| README.MD and docs | 4 | Official project documentation; keep Nuwa-specific README instead. |
| API/changelogs | 84 | Website changelogs; Updater reads API/updater/changelogs instead. |
| API/devices and API/devices.json | 83 | Website device catalog; no Nuwa website API is hosted here. |
| API/downloads | 6 | Website download counters; no local consumer. |
| API/instructions | 80 | Website installation instructions; no Updater consumer. |
| API/team.json | 1 | Official maintainer directory; no local consumer. |
| API/updater/*.json | 82 | Keep only API/updater/nuwa.json. |
| API/updater/changelogs/*.md | 43 | Keep only API/updater/changelogs/nuwa.md. |
| API/updater/CertifiedProps | 2 | Adapt both JSON and APK to this ROM; do not copy the official APK. |

The root updates_new.json and nuwa.md remain for installed ROMs whose overlay
still uses those paths. generate-feed.sh writes both new and legacy feed paths.
Remove the legacy files only after those installed builds no longer need OTA.

## CertifiedProps

This ROM's AttestationService fetches certified_build_props.json. Its
PropImitationHooks reads JSON keys directly as Build or Build.VERSION field
names, so the JSON here uses VERSION.RELEASE, VERSION.INCREMENTAL,
VERSION.SECURITY_PATCH, and VERSION.DEVICE_INITIAL_SDK_INT. The official JSON's
spoof control keys are not consumed by this implementation. The current values
were adapted from the official JSON at the commit above; they may need future
updates and do not guarantee device certification.

The ROM installs net.pixelos.certifiedprops.overlay with versionCode 2 and
platform signing. The published APK has the same package name and resources,
versionCode 2, and is signed with the current ROM platform certificate. The
official APK uses a different package name and older resource values, so it
cannot replace the Nuwa package.

To regenerate the APK after changing the JSON, run from this repository:

    python3 generate-certified-props.py --version-code 3

Increase the version code for every APK update. For a ROM signed with custom
release keys, pass --key and --cert for that ROM's platform signing certificate;
APK updates must match the certificate of the installed base package. Publish
both CertifiedProps files before flashing a ROM whose overlays point here.
