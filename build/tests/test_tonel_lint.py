from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from klibgen_build.tonel_lint import (
    apply_tonel_roundtrip,
    tonel_drift,
    verify_tonel_roundtrip,
)


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

    def test_fix_applies_exported_additions_changes_and_removals(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source/Package"
            exported = root / "exported/Package"
            source.mkdir(parents=True)
            exported.mkdir(parents=True)
            (source / "Changed.class.st").write_text("before\n")
            (source / "Removed.class.st").write_text("removed\n")
            (exported / "Changed.class.st").write_text("after\n")
            (exported / "Added.class.st").write_text("added\n")

            drift = apply_tonel_roundtrip(root / "source", root / "exported")

            self.assertEqual(
                [(item["path"], item["kind"]) for item in drift],
                [
                    ("Package/Added.class.st", "added-by-export"),
                    ("Package/Changed.class.st", "changed-by-export"),
                    ("Package/Removed.class.st", "missing-from-export"),
                ],
            )
            self.assertEqual((source / "Changed.class.st").read_text(), "after\n")
            self.assertEqual((source / "Added.class.st").read_text(), "added\n")
            self.assertFalse((source / "Removed.class.st").exists())
            self.assertEqual(verify_tonel_roundtrip(root / "source", root / "exported"), 2)

    def test_fix_rejects_authoritative_source_changed_since_export(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source/Package"
            expected = root / "expected/Package"
            exported = root / "exported/Package"
            for directory in (source, expected, exported):
                directory.mkdir(parents=True)
            (source / "Fixture.class.st").write_text("concurrent\n")
            (expected / "Fixture.class.st").write_text("before\n")
            (exported / "Fixture.class.st").write_text("after\n")

            with self.assertRaisesRegex(RuntimeError, "changed while its fix was being prepared"):
                apply_tonel_roundtrip(
                    root / "source", root / "exported",
                    expected_source_root=root / "expected",
                )
            self.assertEqual((source / "Fixture.class.st").read_text(), "concurrent\n")

    def test_fix_rolls_back_files_when_application_fails(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source/Package"
            exported = root / "exported/Package"
            source.mkdir(parents=True)
            exported.mkdir(parents=True)
            (source / "Changed.class.st").write_text("before\n")
            (exported / "Changed.class.st").write_text("after\n")
            (exported / "Added.class.st").write_text("added\n")
            real_replace = os.replace
            calls = 0

            def fail_second_replace(from_path, to_path):
                nonlocal calls
                calls += 1
                if calls == 2:
                    raise OSError("disk unavailable")
                real_replace(from_path, to_path)

            with patch("klibgen_build.tonel_lint.os.replace", side_effect=fail_second_replace):
                with self.assertRaisesRegex(OSError, "disk unavailable"):
                    apply_tonel_roundtrip(root / "source", root / "exported")

            self.assertEqual((source / "Changed.class.st").read_text(), "before\n")
            self.assertFalse((source / "Added.class.st").exists())
            self.assertEqual(list(source.glob(".*.tmp")), [])


if __name__ == "__main__":
    unittest.main()
