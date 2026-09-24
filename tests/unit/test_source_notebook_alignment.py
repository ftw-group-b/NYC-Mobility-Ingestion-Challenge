import ast
import json
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


def function_ast(source, function_name):
    tree = ast.parse(source)
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if node.name == function_name:
                return ast.dump(node, include_attributes=False)
    raise AssertionError(f"Function not found: {function_name}")


class SourceNotebookAlignmentTests(unittest.TestCase):
    def test_ingestion_helper_matches_compiled_notebook(self):
        src_common = (
            REPO_ROOT / "src" / "01_ingestion" / "common.py"
        ).read_text()
        notebook = json.loads(
            (
                REPO_ROOT
                / "notebooks"
                / "01_ingestion"
                / "01_ingestion.ipynb"
            ).read_text()
        )
        notebook_python = "\n".join(
            "".join(cell.get("source", []))[len("%python\n") :]
            for cell in notebook["cells"]
            if "def fetch_and_land" in "".join(cell.get("source", []))
        )

        self.assertEqual(
            function_ast(src_common, "fetch_and_land"),
            function_ast(notebook_python, "fetch_and_land"),
            "Update src/01_ingestion/common.py and the compiled notebook together.",
        )

    def test_bronze_sources_keep_rerun_contract(self):
        contracts = {
            "02_green_taxi.sql": [
                "green_tripdata_2026-03.parquet",
                "green_tripdata_2026-04.parquet",
                "green_tripdata_2026-05.parquet",
                "schemaEvolutionMode => 'none'",
            ],
            "03_taxi_zones.sql": [
                "taxi_zone_lookup.csv",
                "schemaEvolutionMode => 'none'",
            ],
            "04_weather_raw.sql": [
                "open_meteo_2026-03-01_2026-05-31.json",
            ],
        }

        bronze_notebook = (
            REPO_ROOT
            / "notebooks"
            / "02_bronze"
            / "02_bronze_load.ipynb"
        ).read_text()
        self.assertIn("def insert_bronze_once", bronze_notebook)
        self.assertIn("IDEMPOTENT_SKIP", bronze_notebook)

        for filename, required_tokens in contracts.items():
            source = (
                REPO_ROOT / "src" / "02_bronze" / filename
            ).read_text()
            self.assertIn("IF NOT EXISTS", source)
            self.assertIn(" BY NAME", source)

            for token in required_tokens:
                self.assertIn(token, source)
                self.assertIn(token, bronze_notebook)


if __name__ == "__main__":
    unittest.main()
