#!/usr/bin/env python3
"""Build a platform-signed CertifiedProps overlay from the published JSON."""

import argparse
import json
import subprocess
import tempfile
from pathlib import Path
from xml.etree import ElementTree as ET

FIELDS = (
    "MANUFACTURER", "BRAND", "MODEL", "DEVICE", "PRODUCT", "HARDWARE",
    "FINGERPRINT", "VERSION.RELEASE", "ID", "VERSION.INCREMENTAL",
    "TYPE", "TAGS", "VERSION.SECURITY_PATCH", "VERSION.DEVICE_INITIAL_SDK_INT",
)
PROPS_URL = "https://raw.githubusercontent.com/PixelOS-Nuwa/PixelOS-OTA/refs/heads/seventeen/API/updater/CertifiedProps/certified_build_props.json"
ANDROID = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID)


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--android-top", type=Path, default=Path(__file__).resolve().parent.parent / "pixelos")
    parser.add_argument("--json", type=Path, default=Path(__file__).resolve().parent / "API/updater/CertifiedProps/certified_build_props.json")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parent / "API/updater/CertifiedProps/certified_build_props.apk")
    parser.add_argument("--version-code", type=int, required=True)
    parser.add_argument("--key", type=Path)
    parser.add_argument("--cert", type=Path)
    args = parser.parse_args()
    if args.version_code < 2:
        parser.error("--version-code must be at least the ROM base overlay version (2)")
    top = args.android_top.resolve()
    aapt2 = top / "out/host/linux-x86/bin/aapt2"
    zipalign = top / "out/host/linux-x86/bin/zipalign"
    apksigner = top / "out/host/linux-x86/bin/apksigner"
    framework = top / "out/target/product/nuwa/system/framework/framework-res.apk"
    key = args.key or top / "build/make/target/product/security/platform.pk8"
    cert = args.cert or top / "build/make/target/product/security/platform.x509.pem"
    props = json.loads(args.json.read_text(encoding="utf-8"))
    if not isinstance(props, dict) or set(props) != set(FIELDS) or any(
        not isinstance(props[k], str) or not props[k] for k in FIELDS
    ):
        parser.error("JSON must contain exactly the supported certified Build properties as nonempty strings")
    with tempfile.TemporaryDirectory(prefix="nuwa-certifiedprops-") as directory:
        temp = Path(directory)
        values = temp / "res/values"
        values.mkdir(parents=True)
        resources = ET.Element("resources")
        array = ET.SubElement(resources, "string-array", {"name": "config_certifiedBuildProperties", "translatable": "false"})
        for field in FIELDS:
            ET.SubElement(array, "item").text = field + ":" + props[field]
        ET.SubElement(resources, "string", {"name": "config_pifUpdateUrl", "translatable": "false"}).text = PROPS_URL
        ET.ElementTree(resources).write(values / "config.xml", encoding="utf-8", xml_declaration=True)
        manifest = ET.Element("manifest", {"package": "net.pixelos.certifiedprops.overlay", f"{{{ANDROID}}}versionCode": str(args.version_code), f"{{{ANDROID}}}versionName": str(args.version_code)})
        ET.SubElement(manifest, "application", {f"{{{ANDROID}}}hasCode": "false"})
        ET.SubElement(manifest, "overlay", {f"{{{ANDROID}}}targetPackage": "android", f"{{{ANDROID}}}priority": "1", f"{{{ANDROID}}}isStatic": "true"})
        ET.ElementTree(manifest).write(temp / "AndroidManifest.xml", encoding="utf-8", xml_declaration=True)
        compiled = temp / "compiled"
        compiled.mkdir()
        run(aapt2, "compile", "--dir", temp / "res", "-o", compiled)
        run(aapt2, "link", "-o", temp / "unsigned.apk", "--manifest", temp / "AndroidManifest.xml", "--min-sdk-version", "37", "--target-sdk-version", "37", "-I", framework, *compiled.glob("*.flat"))
        run(zipalign, "-f", "4", temp / "unsigned.apk", temp / "aligned.apk")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        run(apksigner, "sign", "--key", key, "--cert", cert, "--out", args.output, temp / "aligned.apk")
        run(apksigner, "verify", "--print-certs", args.output)


if __name__ == "__main__":
    main()
