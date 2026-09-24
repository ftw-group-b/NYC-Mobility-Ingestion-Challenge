"""Shared idempotent source-download helper used by ingestion modules."""

import hashlib
import json
import requests
import time
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

REQUEST_HEADERS = {
    "User-Agent": "FTW-B12-Data-Engineering-Course-Project"
}
RETRYABLE_STATUS_CODES = {429, 500, 502, 503, 504}


def _get_with_retry(source_url, timeout, max_attempts, backoff_seconds):
    """Fetch a source with bounded retries for transient HTTP failures."""
    if max_attempts < 1:
        raise ValueError("max_attempts must be at least 1")

    for attempt in range(1, max_attempts + 1):
        try:
            response = requests.get(
                source_url,
                timeout=timeout,
                headers=REQUEST_HEADERS,
            )

            if (
                response.status_code in RETRYABLE_STATUS_CODES
                and attempt < max_attempts
            ):
                time.sleep(backoff_seconds * (2 ** (attempt - 1)))
                continue

            response.raise_for_status()
            return response
        except requests.RequestException:
            if attempt == max_attempts:
                raise
            time.sleep(backoff_seconds * (2 ** (attempt - 1)))

    raise RuntimeError("Source request ended without a response")


def fetch_and_land(
    source_url,
    target_path,
    source_system,
    timeout=120,
    max_attempts=3,
    backoff_seconds=1,
):
    target_path = Path(target_path)
    target_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path = Path(f"{target_path}.metadata.json")

    # First-write-wins idempotency: a rerun reuses the preserved raw file.
    if target_path.exists():
        raw_content = target_path.read_bytes()
        if not raw_content:
            raise ValueError(f"Existing raw file is empty: {target_path}")

        content_hash = hashlib.sha256(raw_content).hexdigest()
        if not metadata_path.exists():
            raise RuntimeError(
                f"Trusted metadata sidecar is missing for {target_path.name}; "
                "do not approve or overwrite the existing raw file automatically."
            )

        metadata = json.loads(metadata_path.read_text())
        expected_metadata = {
            "source_system": source_system,
            "source_url": source_url,
            "source_file": target_path.name,
            "bytes_received": len(raw_content),
            "sha256": content_hash,
        }
        mismatched_fields = [
            field
            for field, expected_value in expected_metadata.items()
            if metadata.get(field) != expected_value
        ]
        if mismatched_fields:
            raise RuntimeError(
                f"Metadata mismatch for {metadata_path.name}: "
                f"{', '.join(mismatched_fields)}. Review the preserved raw "
                "file and sidecar."
            )

        evidence = {
            "action": "IDEMPOTENT_SKIP",
            "http_status": metadata.get("http_status"),
            "source_file": target_path.name,
            "output_path": str(target_path),
            "metadata_path": str(metadata_path),
            "bytes_received": len(raw_content),
            "sha256": content_hash,
        }
        print(json.dumps(evidence, indent=2))
        return evidence

    if metadata_path.exists():
        raise RuntimeError(
            f"Orphan metadata sidecar exists without {target_path.name}; "
            "review and remove the incomplete landing pair before retrying."
        )

    response = _get_with_retry(
        source_url,
        timeout=timeout,
        max_attempts=max_attempts,
        backoff_seconds=backoff_seconds,
    )
    raw_content = response.content
    if not raw_content:
        raise ValueError(f"Empty response received from {source_url}")

    content_hash = hashlib.sha256(raw_content).hexdigest()
    metadata = {
        "source_system": source_system,
        "source_url": source_url,
        "source_file": target_path.name,
        "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
        "http_status": response.status_code,
        "content_type": response.headers.get("Content-Type"),
        "bytes_received": len(raw_content),
        "sha256": content_hash,
    }

    transaction_id = uuid4().hex
    raw_temp_path = target_path.with_name(
        f".{target_path.name}.{transaction_id}.tmp"
    )
    metadata_temp_path = metadata_path.with_name(
        f".{metadata_path.name}.{transaction_id}.tmp"
    )

    raw_committed = False
    try:
        raw_temp_path.write_bytes(raw_content)
        metadata_temp_path.write_text(json.dumps(metadata, indent=2))

        # Same-directory replace is atomic. If the second replace fails, roll
        # back the newly created raw file so a partial pair is not accepted.
        raw_temp_path.replace(target_path)
        raw_committed = True
        metadata_temp_path.replace(metadata_path)
    except Exception:
        if raw_committed and target_path.exists() and not metadata_path.exists():
            target_path.unlink()
        raise
    finally:
        for temp_path in (raw_temp_path, metadata_temp_path):
            if temp_path.exists():
                temp_path.unlink()

    evidence = {
        "action": "WRITTEN",
        "http_status": response.status_code,
        "source_file": target_path.name,
        "output_path": str(target_path),
        "metadata_path": str(metadata_path),
        "bytes_received": len(raw_content),
        "sha256": content_hash,
    }
    print(json.dumps(evidence, indent=2))
    return evidence
