import hashlib
import importlib.util
import json
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[2]
COMMON_PATH = REPO_ROOT / "src" / "01_ingestion" / "common.py"

# Keep this local unit test independent of third-party packages. Databricks
# provides requests at runtime; the tests replace requests.get with a fake.
if "requests" not in sys.modules:
    requests_stub = types.ModuleType("requests")
    requests_stub.RequestException = type(
        "RequestException", (Exception,), {}
    )
    requests_stub.get = None
    sys.modules["requests"] = requests_stub

spec = importlib.util.spec_from_file_location("ingestion_common", COMMON_PATH)
ingestion_common = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(ingestion_common)


class FakeResponse:
    def __init__(self, content=b"new-source-data", status_code=200):
        self.content = content
        self.status_code = status_code
        self.headers = {"Content-Type": "application/octet-stream"}

    def raise_for_status(self):
        if self.status_code >= 400:
            raise ingestion_common.requests.RequestException(
                f"HTTP {self.status_code}"
            )


class FetchAndLandTests(unittest.TestCase):
    def test_new_file_is_written_with_matching_metadata(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            target = Path(temp_dir) / "source.bin"

            with patch.object(
                ingestion_common.requests,
                "get",
                return_value=FakeResponse(),
            ) as get:
                evidence = ingestion_common.fetch_and_land(
                    "https://example.test/source.bin",
                    target,
                    "test_source",
                )

            self.assertEqual(evidence["action"], "WRITTEN")
            self.assertEqual(target.read_bytes(), b"new-source-data")
            get.assert_called_once()

            metadata = json.loads(
                Path(f"{target}.metadata.json").read_text()
            )
            self.assertEqual(
                metadata["sha256"],
                hashlib.sha256(b"new-source-data").hexdigest(),
            )

    def test_existing_valid_file_skips_without_network_request(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            target = Path(temp_dir) / "source.bin"
            target.write_bytes(b"preserved-source-data")
            digest = hashlib.sha256(target.read_bytes()).hexdigest()
            Path(f"{target}.metadata.json").write_text(
                json.dumps(
                    {
                        "source_system": "test_source",
                        "source_url": "https://example.test/source.bin",
                        "source_file": target.name,
                        "bytes_received": len(target.read_bytes()),
                        "sha256": digest,
                        "http_status": 200,
                    }
                )
            )

            with patch.object(
                ingestion_common.requests,
                "get",
                side_effect=AssertionError("network must not be called"),
            ) as get:
                evidence = ingestion_common.fetch_and_land(
                    "https://example.test/source.bin",
                    target,
                    "test_source",
                )

            self.assertEqual(evidence["action"], "IDEMPOTENT_SKIP")
            self.assertEqual(target.read_bytes(), b"preserved-source-data")
            get.assert_not_called()

    def test_existing_file_with_wrong_metadata_hash_fails(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            target = Path(temp_dir) / "source.bin"
            target.write_bytes(b"preserved-source-data")
            Path(f"{target}.metadata.json").write_text(
                json.dumps({"sha256": "wrong-hash"})
            )

            with self.assertRaisesRegex(RuntimeError, "Metadata mismatch"):
                ingestion_common.fetch_and_land(
                    "https://example.test/source.bin",
                    target,
                    "test_source",
                )

    def test_existing_file_without_sidecar_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            target = Path(temp_dir) / "source.bin"
            target.write_bytes(b"unverified-source-data")

            with patch.object(
                ingestion_common.requests,
                "get",
                side_effect=AssertionError("network must not be called"),
            ) as get:
                with self.assertRaisesRegex(
                    RuntimeError,
                    "Trusted metadata sidecar is missing",
                ):
                    ingestion_common.fetch_and_land(
                        "https://example.test/source.bin",
                        target,
                        "test_source",
                    )

            get.assert_not_called()

    def test_transient_http_failure_is_retried(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            target = Path(temp_dir) / "source.bin"

            with (
                patch.object(
                    ingestion_common.requests,
                    "get",
                    side_effect=[
                        FakeResponse(status_code=503),
                        FakeResponse(),
                    ],
                ) as get,
                patch.object(ingestion_common.time, "sleep") as sleep,
            ):
                evidence = ingestion_common.fetch_and_land(
                    "https://example.test/source.bin",
                    target,
                    "test_source",
                    max_attempts=2,
                    backoff_seconds=0.01,
                )

            self.assertEqual(evidence["action"], "WRITTEN")
            self.assertEqual(get.call_count, 2)
            sleep.assert_called_once_with(0.01)

    def test_orphan_sidecar_without_raw_file_fails(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            target = Path(temp_dir) / "source.bin"
            Path(f"{target}.metadata.json").write_text("{}")

            with self.assertRaisesRegex(RuntimeError, "Orphan metadata"):
                ingestion_common.fetch_and_land(
                    "https://example.test/source.bin",
                    target,
                    "test_source",
                )


if __name__ == "__main__":
    unittest.main()
