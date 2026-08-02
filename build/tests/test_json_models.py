from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from pydantic import ValidationError

from klibgen_build.json_models import (
    ALL_MODELS,
    MODEL_BY_SCHEMA,
    ArtifactV1,
    InventoryV2,
    SessionCompletionV1,
    parse_named_record,
    validate_named_record,
)
from klibgen_build.tonel_export import INDEX_BEGIN, INDEX_END, export_tonel, render_model


class JsonModelTest(unittest.TestCase):
    def test_named_registry_is_unique_and_dispatches_exact_schema(self) -> None:
        self.assertEqual(len(MODEL_BY_SCHEMA), len(set(MODEL_BY_SCHEMA)))
        completion = parse_named_record({
            "schema": "klibgen.session-completion/1",
            "sessionId": "session-1",
            "state": "succeeded",
            "ok": True,
        })
        self.assertIsInstance(completion, SessionCompletionV1)
        self.assertEqual(completion.to_wire()["sessionId"], "session-1")
        with self.assertRaisesRegex(ValueError, "unknown named"):
            parse_named_record({"schema": "klibgen.unknown/1"})

    def test_extensible_records_preserve_unknown_fields_and_are_frozen(self) -> None:
        artifact = ArtifactV1.model_validate({
            "schema": "klibgen.artifact/1",
            "schemaVersion": 1,
            "artifactType": "project-image",
            "outputKey": "a" * 64,
            "producingRole": "project-finalize",
            "payloadShapeDigest": "b" * 64,
            "platform": "linux-x86_64",
            "presentation": {"native": "hardlink"},
        })
        self.assertEqual(artifact.to_wire()["presentation"], {"native": "hardlink"})
        with self.assertRaises(ValidationError):
            artifact.output_key = "changed"

    def test_inventory_models_nested_records_and_malformed_entries(self) -> None:
        value = {
            "schema": "klibgen.inventory/2",
            "schemaVersion": 2,
            "operation": "inventory",
            "generatedAt": "2026-08-03T10:00:00+00:00",
            "nodes": [],
            "edges": [],
            "warnings": [],
            "stateRoot": "/state/v2",
            "recipes": [],
            "targets": [],
            "artifacts": [],
            "references": [{"path": "/bad.json", "malformed": True, "error": "bad JSON"}],
            "workspaces": [],
            "stagingAreas": [],
            "activeSessions": [],
            "statuses": [],
            "locks": [],
            "storage": {"logicalBytes": 0, "allocatedBytes": 0, "fileCount": 0},
        }
        model = InventoryV2.model_validate(value)
        self.assertEqual(model.references[0].error, "bad JSON")
        self.assertEqual(validate_named_record(value), value)

    def test_every_model_renders_deterministic_tonel(self) -> None:
        first = {model.smalltalk_name: render_model(model) for model in ALL_MODELS}
        second = {model.smalltalk_name: render_model(model) for model in reversed(ALL_MODELS)}
        self.assertEqual(first, second)
        self.assertTrue(all("DO NOT EDIT" in source for source in first.values()))

    def test_export_check_detects_drift_and_preserves_handwritten_files(self) -> None:
        temporary_root = Path(__file__).resolve().parents[2] / "tmp"
        temporary_root.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=temporary_root) as directory:
            root = Path(directory)
            output = root / "src/KlibGenGt-JsonModels"
            core = root / "src/KlibGenGt-Core"
            output.mkdir(parents=True)
            core.mkdir(parents=True)
            handwritten = output / "KGHandwritten.class.st"
            handwritten.write_text("Class { #name : 'KGHandwritten' }\n", encoding="utf-8")
            (core / "KlibGenGt.class.st").write_text(
                f'"Index\n{INDEX_BEGIN}\n{INDEX_END}\n"\nClass {{ #name : \'KlibGenGt\' }}\n',
                encoding="utf-8",
            )
            self.assertTrue(export_tonel(output, check=True))
            export_tonel(output)
            self.assertEqual(export_tonel(output, check=True), [])
            self.assertTrue(handwritten.is_file())
            generated = next(path for path in output.glob("*.class.st") if path != handwritten)
            generated.write_text("stale", encoding="utf-8")
            self.assertIn(generated.name, export_tonel(output, check=True))


if __name__ == "__main__":
    unittest.main()
