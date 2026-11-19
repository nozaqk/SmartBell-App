import json
import unittest
from unittest.mock import patch

from tool import prune_release_apks as retention


class RetentionTest(unittest.TestCase):
    def setUp(self):
        self.keep = {"id": 31, "name": "latest.apk", "state": "uploaded", "size": 100}
        self.latest = {"id": 3, "tag_name": "v3", "draft": False, "prerelease": False,
                       "assets": [self.keep, {"id": 32, "name": "split.APK"}]}
        self.old = {"id": 2, "tag_name": "v2", "draft": False,
                    "assets": [{"id": 21, "name": "latest.apk"}, {"id": 22, "name": "latest.apk.sha256"}]}
        self.draft = {"id": 4, "tag_name": "v4", "draft": True, "assets": [{"id": 41, "name": "preview.apk"}]}
        self.releases = [self.latest, self.old, self.draft]
        self.deleted = []
        mock = patch.object(retention, "api", side_effect=self.fake_api)
        mock.start()
        self.addCleanup(mock.stop)

    def fake_api(self, endpoint, *args):
        base = retention.RELEASES
        if endpoint == f"{base}/latest":
            return json.dumps(self.latest)
        if args == ("--method", "DELETE"):
            self.assertTrue(endpoint.startswith(f"{base}/assets/"))
            asset_id = int(endpoint.rsplit("/", 1)[1])
            self.deleted.append(asset_id)
            for release in self.releases:
                release["assets"] = [a for a in release["assets"] if a["id"] != asset_id]
            return ""
        self.assertIn("--paginate", args)
        pages = {f"{base}?per_page=100": self.releases}
        for release in self.releases:
            pages[f"{base}/{release['id']}/assets?per_page=100"] = release["assets"]
        return "\n".join(json.dumps(item) for item in pages[endpoint])

    def test_only_latest_public_apk_survives_and_rerun_is_a_noop(self):
        retention.prune("v3")
        retention.prune("v3")
        self.assertCountEqual(self.deleted, [21, 32])
        self.assertEqual(self.latest["assets"], [self.keep])
        self.assertEqual(self.old["assets"][0]["name"], "latest.apk.sha256")
        self.assertEqual(self.draft["assets"][0]["name"], "preview.apk")

    def test_wrong_tag_or_incomplete_upload_does_not_delete_anything(self):
        with self.assertRaises(RuntimeError):
            retention.prune("v2")
        for field, value in [("state", "starter"), ("size", 0), ("name", "other.apk")]:
            with self.subTest(field=field), patch.dict(self.keep, {field: value}), self.assertRaises(RuntimeError):
                retention.prune("v3")
        self.assertEqual(self.deleted, [])

    def test_stop_if_canonical_apk_changes_during_inventory(self):
        with patch.object(retention, "latest_apk_id", side_effect=[31, 35]), self.assertRaises(RuntimeError):
            retention.prune("v3")
        self.assertEqual(self.deleted, [])
