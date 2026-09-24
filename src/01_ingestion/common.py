"""Shared idempotent source-download helper used by ingestion modules."""

import hashlib
import json
import requests
from datetime import datetime, timezone
from pathlib import Path

REQUEST_HEADERS = {
    "User-Agent": "FTW-B12-Data-Engineering-Course-Project"
}

def fetch_and_land(source_url, target_path, source_system, timeout=120):
    target_path = Path(target_path)
    target_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path = Path(f"{target_path}.metadata.json")

    # First-write-wins idempotency: a rerun reuses the preserved raw file.
    if target_path.exists():
        raw_content = target_path.read_bytes()
        if not raw_content:
            raise ValueError(f"Existing raw file is empty: {target_path}")

        content_hash = hashlib.sha256(raw_content).hexdigest()
        if metadata_path.exists():
            metadata = json.loads(metadata_path.read_text())
            if metadata.get("sha256") != content_hash:
                raise RuntimeError(
                    f"Metadata hash mismatch for {metadata_path.name}; "
                    "review the preserved raw file and sidecar."
                )
        else:
            metadata = {
                "source_system": source_system,
                "source_url": source_url,
                "source_file": target_path.name,
                "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
                "http_status": None,
                "content_type": None,
                "bytes_received": len(raw_content),
                "sha256": content_hash,
                "metadata_rebuilt_from_existing_file": True,
            }
            metadata_path.write_text(json.dumps(metadata, indent=2))

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

    response = requests.get(
        source_url,
        timeout=timeout,
        headers=REQUEST_HEADERS,
    )
    response.raise_for_status()
    raw_content = response.content
    if not raw_content:
        raise ValueError(f"Empty response received from {source_url}")

    content_hash = hashlib.sha256(raw_content).hexdigest()
    target_path.write_bytes(raw_content)

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
    metadata_path.write_text(json.dumps(metadata, indent=2))

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
