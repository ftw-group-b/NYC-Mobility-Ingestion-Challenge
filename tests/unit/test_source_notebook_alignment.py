import ast
import json
import re
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


def normalized_sql(source):
    source = re.sub(r"(?m)^%sql\s*", "", source)
    source = re.sub(r"--.*", "", source)
    return re.sub(r"\s+", " ", source).strip().lower()


def normalized_notebook_sql(relative_paths):
    statements = []
    for relative_path in relative_paths:
        notebook = json.loads((REPO_ROOT / relative_path).read_text())
        statements.extend(
            normalized_sql("".join(cell.get("source", [])))
            for cell in notebook["cells"]
        )
    return " ".join(statements)


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
        self.assertEqual(
            function_ast(src_common, "_get_with_retry"),
            function_ast(notebook_python, "_get_with_retry"),
            "Update the retry helper in source and notebook together.",
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

    def test_modular_sql_is_present_in_compiled_layer_notebooks(self):
        layer_contracts = {
            (
                "notebooks/03_silver/01_silver_green_taxi.ipynb",
                "notebooks/03_silver/02_silver_taxi_zones.ipynb",
                "notebooks/03_silver/03_silver_weather.ipynb",
            ): [
                "src/03_silver/00_create_silver_schema.sql",
                "src/03_silver/01_green_taxi.sql",
                "src/03_silver/02_taxi_zones.sql",
                "src/03_silver/03_weather.sql",
            ],
            ("notebooks/04_gold/01_gold_mart_creation.ipynb",): [
                "src/04_gold/00_create_gold_schema.sql",
                "src/04_gold/01_dim_date.sql",
                "src/04_gold/02_dim_time.sql",
                "src/04_gold/03_dim_taxi_zone.sql",
                "src/04_gold/04_dim_weather_hour.sql",
                "src/04_gold/05_fact_green_taxi_trip.sql",
            ],
            ("notebooks/05_analytics/01_business_analytics.ipynb",): [
                "src/05_analytics/01_taxi_demand.sql",
                "src/05_analytics/02_weather_behavior.sql",
                "src/05_analytics/03_area_mobility_patterns.sql",
            ],
            (
                "notebooks/06_dashboard/01_data_quality_dashboard_views.ipynb",
            ): [
                f"src/06_data_quality/{index:02d}_{name}.sql"
                for index, name in [
                    (1, "referential_integrity"),
                    (2, "overview"),
                    (3, "check_scores"),
                    (4, "dimension_scores"),
                    (5, "canonical_dimensions"),
                    (6, "problem_areas"),
                    (7, "outside_analysis_window"),
                    (8, "row_reconciliation"),
                    (9, "zone_hotspots"),
                ]
            ],
        }

        for notebook_paths, source_paths in layer_contracts.items():
            compiled_sql = normalized_notebook_sql(notebook_paths)
            for source_path in source_paths:
                with self.subTest(source=source_path):
                    modular_sql = normalized_sql(
                        (REPO_ROOT / source_path).read_text()
                    )
                    self.assertIn(
                        modular_sql,
                        compiled_sql,
                        f"Update {source_path} and its compiled notebook together.",
                    )


if __name__ == "__main__":
    unittest.main()
