from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from klibgen_build.tonel_lint import tonel_drift, verify_tonel_roundtrip


class TonelLintTest(unittest.TestCase):
    def test_identical_tonel_trees_pass(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            exported = root / "exported"
            for tree in (source, exported):
                package = tree / "KlibGenGt-Fixture"
                package.mkdir(parents=True)
                (package / "Fixture.class.st").write_text("Fixture >> value [\n\t^ 42\n]\n", encoding="utf-8")
            self.assertEqual(verify_tonel_roundtrip(source, exported), 1)
            self.assertEqual(tonel_drift(source, exported), [])

    def test_changed_added_and_missing_tonel_files_report_exact_drift(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            exported = root / "exported"
            (source / "Package").mkdir(parents=True)
            (exported / "Package").mkdir(parents=True)
            (source / "Package/Changed.class.st").write_text("before\n", encoding="utf-8")
            (exported / "Package/Changed.class.st").write_text("after\n", encoding="utf-8")
            (source / "Package/Missing.class.st").write_text("missing\n", encoding="utf-8")
            (exported / "Package/Added.class.st").write_text("added\n", encoding="utf-8")
            drift = tonel_drift(source, exported)
            self.assertEqual(
                [(item["path"], item["kind"]) for item in drift],
                [
                    ("Package/Added.class.st", "added-by-export"),
                    ("Package/Changed.class.st", "changed-by-export"),
                    ("Package/Missing.class.st", "missing-from-export"),
                ],
            )
            with self.assertRaisesRegex(ValueError, "Tonel source is not canonical"):
                verify_tonel_roundtrip(source, exported)

    def test_non_smalltalk_files_are_outside_the_round_trip_contract(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            exported = root / "exported"
            source.mkdir()
            exported.mkdir()
            (source / ".properties").write_text("source", encoding="utf-8")
            (exported / ".properties").write_text("exported", encoding="utf-8")
            self.assertEqual(verify_tonel_roundtrip(source, exported), 0)


if __name__ == "__main__":
    unittest.main()
