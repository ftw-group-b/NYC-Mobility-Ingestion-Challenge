# Ingestion

`01_ingestion.ipynb` loads the three approved source families into the landing location, records stable source identifiers, and demonstrates repeatable monthly ingestion for March-May 2026.

Landing is first-write-wins. Existing files are verified locally against their
SHA-256 metadata sidecars and skipped without another download. New content is
landed under a new versioned filename rather than overwriting preserved raw data.
