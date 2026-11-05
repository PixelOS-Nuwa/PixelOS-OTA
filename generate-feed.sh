#!/usr/bin/env bash

# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
android_top="$script_dir/../pixelos"
artifact=
output="$script_dir/API/updater/nuwa.json"
url=
incremental=
incremental_url=

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

usage() {
    printf 'Usage: %s OTA.zip [--incremental DELTA.zip] [--url PUBLIC_HTTPS_URL] [--incremental-url PUBLIC_HTTPS_URL] [--android-top ANDROID_SOURCE] [--output JSON_PATH]\n' "$0"
}

while (($#)); do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --url|--output|--android-top|--incremental|--incremental-url)
            (($# >= 2)) || die "$1 requires a value"
            case "$1" in
                --url) url=$2 ;;
                --output) output=$2 ;;
                --android-top) android_top=$2 ;;
                --incremental) incremental=$2 ;;
                --incremental-url) incremental_url=$2 ;;
            esac
            shift 2
            ;;
        -*) die "Unknown option: $1" ;;
        *) [[ -z "$artifact" ]] || die "Exactly one ZIP is required"; artifact=$1; shift ;;
    esac
done

[[ -n "$artifact" && -f "$artifact" ]] || die "OTA ZIP not found: $artifact"
if [[ -n "$incremental" && ! -f "$incremental" ]]; then
    die "Incremental OTA ZIP not found: $incremental"
fi
if [[ -n "$incremental_url" && -z "$incremental" ]]; then
    die "--incremental-url requires --incremental"
fi
zip_name=${artifact##*/}
[[ "$zip_name" =~ ^PixelOS_nuwa-([0-9]+\.[0-9]+)-[0-9]{8}-[0-9]{4}\.zip$ ]] || \
    die "Expected PixelOS_nuwa-VERSION-YYYYMMDD-HHMM.zip"
version=${BASH_REMATCH[1]}
url=${url:-"https://downloads.sourceforge.net/project/aosp-nuwa/PixelOS/$zip_name"}
if [[ -n "$incremental" ]]; then
    incremental_name=${incremental##*/}
    incremental_url=${incremental_url:-"https://downloads.sourceforge.net/project/aosp-nuwa/PixelOS/$incremental_name"}
fi
[[ "$url" == https://* ]] || die "OTA URL must use HTTPS"
if [[ -n "$incremental" ]]; then
    [[ "$incremental_url" == https://* ]] || die "Incremental OTA URL must use HTTPS"
fi
generator="$android_top/packages/apps/Updater/tools/pixelos_feed.py"
[[ -x "$generator" ]] || die "Missing Updater feed generator: $generator"
command -v curl >/dev/null || die "curl is required"
command -v python3 >/dev/null || die "python3 is required"

python3 - "$artifact" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    metadata = archive.read("META-INF/com/android/metadata").decode("utf-8")
device = next((line.partition("=")[2].strip() for line in metadata.splitlines()
               if line.startswith("pre-device=")), None)
if device != "nuwa":
    raise SystemExit(f"OTA pre-device must be nuwa, got {device!r}")
PY

output_dir=$(dirname -- "$output")
mkdir -p -- "$output_dir"
temporary=$(mktemp "$output_dir/.nuwa.json.XXXXXX")
headers=$(mktemp)
incremental_headers=$(mktemp)
trap 'rm -f -- "$temporary" "$headers" "$incremental_headers"' EXIT

status=$(curl --silent --show-error --head --location --retry 3 \
    --retry-delay 2 --connect-timeout 20 --max-time 180 \
    --dump-header "$headers" --output /dev/null --write-out '%{http_code}' "$url") || \
    die "Cannot reach OTA URL: $url"
[[ "$status" == 200 ]] || die "OTA URL returned HTTP $status: $url"
remote_size=$(awk '
    /^HTTP\// { size="" }
    tolower($1) == "content-length:" { size=$2 }
    END { gsub(/\r/, "", size); print size }
' "$headers")
[[ "$remote_size" =~ ^[0-9]+$ && "$remote_size" -gt 0 ]] || \
    die "OTA URL did not report Content-Length"
local_size=$(stat -Lc '%s' "$artifact")
[[ "$remote_size" == "$local_size" ]] || \
    die "OTA size mismatch: local=$local_size remote=$remote_size"

python3 "$generator" generate-ota "$artifact" \
    --url "$url" --version "$version" --output "$temporary"
python3 - "$temporary" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
feed = json.loads(path.read_text(encoding="utf-8"))
# The SourceForge URL redirects, so Updater must download the whole package.
feed[0]["files"][0].pop("ota_property_files", None)
path.write_text(json.dumps(feed, indent=2) + "\n", encoding="utf-8")
PY
python3 "$generator" validate-ota "$temporary"
if [[ -n "$incremental" ]]; then
    delta_status=$(curl --silent --show-error --head --location --retry 3 \
        --retry-delay 2 --connect-timeout 20 --max-time 180 \
        --dump-header "$incremental_headers" --output /dev/null \
        --write-out '%{http_code} %{url_effective}' \
        "$incremental_url") || die "Cannot reach incremental OTA URL: $incremental_url"
    read -r delta_status incremental_resolved_url <<< "$delta_status"
    [[ "$delta_status" == 200 ]] || die "Incremental URL returned HTTP $delta_status: $incremental_url"
    delta_remote_size=$(awk '
        /^HTTP\// { size="" }
        tolower($1) == "content-length:" { size=$2 }
        END { gsub(/\r/, "", size); print size }
    ' "$incremental_headers")
    delta_local_size=$(stat -Lc '%s' "$incremental")
    [[ "$delta_remote_size" =~ ^[0-9]+$ && "$delta_remote_size" == "$delta_local_size" ]] || \
        die "Incremental URL size mismatch: local=$delta_local_size remote=${delta_remote_size:-unknown}"

    range_status=$(curl --silent --show-error --retry 2 \
        --connect-timeout 20 --max-time 60 --max-filesize 1 --range 0-0 \
        --dump-header "$incremental_headers" --output /dev/null \
        --write-out '%{http_code}' "$incremental_resolved_url") || \
        die "Incremental URL does not support HTTP Range: $incremental_resolved_url"
    [[ "$range_status" == 206 ]] || \
        die "Incremental URL must support HTTP Range (expected 206, got $range_status)"
    content_range=$(awk 'tolower($1) == "content-range:" { value=$2 " " $3 } END { gsub(/\r/, "", value); print value }' "$incremental_headers")
    [[ "$content_range" == "bytes 0-0/$delta_local_size" ]] || \
        die "Unexpected incremental Content-Range: ${content_range:-missing}"

    incremental_feed=$(mktemp)
    trap 'rm -f -- "$temporary" "$headers" "$incremental_headers" "$incremental_feed"' EXIT
    python3 "$generator" add-incremental "$temporary" "$incremental" \
        --full-artifact "$artifact" --url "$incremental_url" --output "$incremental_feed"
    mv -f -- "$incremental_feed" "$temporary"
    python3 "$generator" validate-ota "$temporary" --incremental-artifact "$incremental"
fi
mv -f -- "$temporary" "$output"
printf 'Generated %s from %s\n' "$output" "$artifact"
