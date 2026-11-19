"""Smoke checks for the native resources produced by tool/setup_platforms.sh."""

import json
import struct
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


def png_info(path):
    with path.open("rb") as png:
        header = png.read(26)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"Not a PNG: {path}")
    return struct.unpack(">IIBB", header[16:26])  # width, height, depth, colour type


class NativeAppIconsTest(unittest.TestCase):
    def test_android_launcher_and_notification_resources(self):
        main = Path("android/app/src/main")
        res = main / "res"
        android = "{http://schemas.android.com/apk/res/android}"
        app = ET.parse(main / "AndroidManifest.xml").getroot().find("application")
        self.assertEqual(app.get(android + "icon"), "@mipmap/ic_launcher")
        adaptive = ET.parse(res / "mipmap-anydpi-v26/ic_launcher.xml").getroot()
        for layer in ("foreground", "monochrome"):
            resource = "ic_launcher_" + layer
            self.assertIn("@drawable/" + resource, [e.get(android + "drawable") for e in adaptive.find(layer).iter()])
            self.assertTrue((res / f"drawable-mdpi/{resource}.png").is_file())
        self.assertEqual(png_info(res / "mipmap-mdpi/ic_launcher.png")[:2], (48, 48))
        defaults = {m.get(android + "name"): m.get(android + "resource") for m in app.findall("meta-data")}
        self.assertEqual(defaults.get("com.google.firebase.messaging.default_notification_icon"), "@drawable/ic_launcher_foreground")

    def test_ios_catalog_has_complete_opaque_icons(self):
        catalog = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
        entries = json.loads((catalog / "Contents.json").read_text())["images"]
        self.assertIn("1024x1024", {entry["size"] for entry in entries})
        for entry in entries:
            with self.subTest(filename=entry["filename"]):
                size = int(float(entry["size"].split("x")[0]) * int(entry["scale"].rstrip("x")))
                self.assertEqual(png_info(catalog / entry["filename"]), (size, size, 8, 2))  # opaque RGB
