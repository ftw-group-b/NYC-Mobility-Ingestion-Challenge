import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SETUP_CLI_SHA = "8821c27b1fe57472264eeb6e50c1f31d69552f28"


class RepositoryGovernanceTests(unittest.TestCase):
    def test_ci_runs_unit_tests_and_parses_python_notebook_cells(self):
        workflow = (REPO_ROOT / ".github/workflows/ci.yml").read_text()
        self.assertIn("python -m unittest discover", workflow)
        self.assertIn("ast.parse(python_source", workflow)

    def test_deployment_actions_are_pinned_and_production_is_protected(self):
        production = (
            REPO_ROOT / ".github/workflows/deploy-databricks.yml"
        ).read_text()
        preview = (
            REPO_ROOT / ".github/workflows/deploy-databricks-preview.yml"
        ).read_text()

        for workflow in (production, preview):
            self.assertIn(f"databricks/setup-cli@{SETUP_CLI_SHA}", workflow)
            self.assertNotIn("databricks/setup-cli@main", workflow)
            self.assertIn("version: 1.10.0", workflow)

        self.assertRegex(
            production,
            r"environment:\s+name: production",
        )

    def test_bundle_and_job_have_production_safety_limits(self):
        bundle = (REPO_ROOT / "databricks.yml").read_text()
        job = (
            REPO_ROOT / "resources/nyc_mobility_job.yml"
        ).read_text()

        self.assertRegex(bundle, r"prod:\s+mode: production")
        task_count = len(
            re.findall(r"^        - task_key:", job, re.MULTILINE)
        )
        timeout_count = len(
            re.findall(r"^\s+timeout_seconds:", job, re.MULTILINE)
        )
        self.assertEqual(task_count, 16)
        self.assertEqual(timeout_count, task_count + 1)
        self.assertEqual(job.count("max_retries:"), 2)

    def test_only_one_end_to_end_gate_is_executable(self):
        gates = sorted(
            path.name
            for path in (REPO_ROOT / "tests/end_to_end").glob("*.ipynb")
        )
        self.assertEqual(
            gates,
            ["02_great_expectations_quality_gate.ipynb"],
        )
        self.assertTrue(
            (
                REPO_ROOT
                / "docs/archive/01_legacy_end_to_end_quality_gate.ipynb"
            ).is_file()
        )

    def test_operations_and_ownership_are_documented(self):
        required_files = [
            ".github/CODEOWNERS",
            "docs/operations/RUNBOOK.md",
            "docs/operations/CONFIGURATION.md",
            "docs/operations/CHANGE_CHECKLIST.md",
        ]
        for relative_path in required_files:
            with self.subTest(path=relative_path):
                path = REPO_ROOT / relative_path
                self.assertTrue(path.is_file())
                self.assertTrue(path.read_text().strip())


if __name__ == "__main__":
    unittest.main()
