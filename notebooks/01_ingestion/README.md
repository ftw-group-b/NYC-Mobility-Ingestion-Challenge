# Ingestion

`01_ingestion.ipynb` loads the three approved source families into the landing location, records stable source identifiers, and demonstrates repeatable monthly ingestion for March-May 2026.

Landing is first-write-wins. Existing files are verified locally against their
trusted SHA-256 metadata sidecars and skipped without another download. Missing
or mismatched metadata stops the task for manual review. Temporary HTTP failures
receive bounded retries, and new file/sidecar pairs are staged through temporary
files. New content is landed under a new versioned filename rather than
overwriting preserved raw data.
