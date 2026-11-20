# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Mercedes-Benz Group AG
from pathlib import Path

import pytest
import yaml
from dbt.tests.util import run_dbt, run_dbt_and_capture, run_sql_with_adapter
from tests.functional.fixtures import IterativeSnapshot
from tests.functional.test_case_7 import *
# Imported as a module so pytest doesn't collect the base suite a second time from this file
import tests.functional.test_iterative_snapshot as base_suite


# run in terminal:
# pytest tests/functional/test_materialize_staging.py -s
#
# Runs every scenario of the base suite (test_case_0 .. test_case_6) with materialize_staging=true, once with
# enable_temp_views=true and once with enable_temp_views=false, plus a reappearing-record scenario that is
# compared against a run with the default (temporary view) configuration.

HELPER_TABLE_MARKERS = ("__src_", "__dbt_tmp_")
# Separator of the single join key, as it appears in the generated SQL
SINGLE_KEY_SEPARATOR = "'\\u001f'"
PACKAGE_PROJECT_FILE = Path(__file__).resolve().parents[2] / "dbt_project.yml"

# Test-only change to the event hook: fails the model inside the sequence loop, after the source helper table was created
EVENT_HOOK_SIGNATURE = "{% macro default__iterative_snapshot_on_event(event_type, model_name, relation, details) %}"
FAILING_EVENT_HOOK = EVENT_HOOK_SIGNATURE + """
    {%- if var('pytest_fail_on_event', false) -%}
        {{ exceptions.raise_compiler_error('pytest: failing on event ' ~ event_type) }}
    {%- endif -%}
"""


class _PhysicalStagingSuite(base_suite.TestIterativeSnapshot):
    """Base suite with materialize_staging=true. Subclasses set enable_temp_views."""

    enable_temp_views = True

    @pytest.fixture(scope="class")
    def project_config_update(self, project_config_update):
        return {
            **project_config_update,
            "vars": {
                **project_config_update["vars"],
                "materialize_staging": True,
                "enable_temp_views": self.enable_temp_views,
            },
            # The test project replaces the package, so take the hook from the package's own config
            "on-run-end": yaml.safe_load(PACKAGE_PROJECT_FILE.read_text(encoding="utf-8"))["on-run-end"],
        }

    @pytest.fixture(scope="class")
    def macros(self):
        macros = {
            file.name: file.read_text(encoding="utf-8")
            for file in base_suite.MACRO_FOLDER_PATH.rglob("*.sql")
            if not file.name.startswith(".")
        }
        return {**macros, "events.sql": macros["events.sql"].replace(EVENT_HOOK_SIGNATURE, FAILING_EVENT_HOOK)}

    @staticmethod
    def _helper_tables(project, parameters):
        rows = run_sql_with_adapter(
            project.adapter,
            f"SHOW TABLES IN `{parameters['catalog']}`.`{parameters['schema']}` "
            f"LIKE '{parameters['snapshot_table']}__*'",
            fetch="all",
        )
        return [row[1] for row in rows if any(marker in row[1] for marker in HELPER_TABLE_MARKERS)]

    @pytest.fixture(autouse=True)
    def assert_helper_tables_dropped(self, project, parameters):
        """No test may leave a new helper table behind. Tables from earlier aborted runs in the shared schema are ignored."""
        existing = set(self._helper_tables(project, parameters))
        yield
        leftovers = set(self._helper_tables(project, parameters)) - existing
        assert not leftovers, f"Helper tables not dropped: {sorted(leftovers)}"

    @staticmethod
    def _reset_tables(project, parameters):
        base = IterativeSnapshot(**parameters)
        for table in ("source_table", "snapshot_table", "meta_table", "error_table"):
            run_sql_with_adapter(project.adapter, base.drop_table(table_name=parameters[table]))

    @staticmethod
    def _load_reappearing_record_scenario(project, parameters, extra_args=()):
        """Loads test case 7 in two runs and returns the dbt log output of both snapshot runs."""
        base = IterativeSnapshot(**parameters)
        run_dbt(["run", "--select", "tag:source"])

        run_sql_with_adapter(project.adapter, base.insert_values(values=t7_insert_batch_1))
        _, log_1 = run_dbt_and_capture(["run", "--select", "tag:snapshot", *extra_args])

        run_sql_with_adapter(project.adapter, base.insert_values(values=t7_insert_batch_2))
        _, log_2 = run_dbt_and_capture(["run", "--select", "tag:snapshot", *extra_args])

        return log_1 + log_2

    #############################################################################################
    # TEST CASE - 7 - reappearing record across multiple sequences, physical staging
    #############################################################################################

    def test_case_7_reappearing_record(self, project, parameters, setup_and_teardown):

        """ default config run -> reset -> materialize_staging run -> compare history and SCD2 invariants """

        base = IterativeSnapshot(**parameters)
        snapshot = f"`{parameters['catalog']}`.`{parameters['schema']}`.`{parameters['snapshot_table']}`"

        # Baseline: same scenario with the default temporary view path
        self._load_reappearing_record_scenario(
            project, parameters,
            extra_args=["--vars", "{materialize_staging: false, enable_temp_views: true}"],
        )
        expected_result = run_sql_with_adapter(project.adapter, base.generate_actual_sql(), fetch="all")

        self._reset_tables(project, parameters)

        log_output = self._load_reappearing_record_scenario(project, parameters)
        actual_result = run_sql_with_adapter(project.adapter, base.generate_actual_sql(), fetch="all")

        # Physical staging takes precedence over enable_temp_views
        assert "Materializing source data for" in log_output
        assert "Created temporary source view" not in log_output

        # Same SCD2 history as the temporary view path
        assert (
            expected_result == actual_result
        ), f"Expected {expected_result}, but got {actual_result}"

        # Repaired timeline: every closed version ends where the next version of the same key starts
        gaps = run_sql_with_adapter(project.adapter, f"""
            SELECT uk1, uk2, dbt_valid_from, dbt_valid_to, next_valid_from
            FROM (
                SELECT uk1, uk2, dbt_valid_from, dbt_valid_to,
                       LEAD(dbt_valid_from) OVER (PARTITION BY uk1, uk2 ORDER BY dbt_valid_from) AS next_valid_from
                FROM {snapshot}
            )
            WHERE next_valid_from IS NOT NULL
              AND (dbt_valid_to IS NULL OR dbt_valid_to != next_valid_from)
        """, fetch="all")
        assert not gaps, f"SCD2 validity gaps: {gaps}"

        # Exactly one current version per key, with the latest values
        current = run_sql_with_adapter(project.adapter, f"""
            SELECT uk1, uk2, attribute1
            FROM {snapshot}
            WHERE dbt_valid_to IS NULL
            ORDER BY uk1, uk2
        """, fetch="all")
        actual_current = [(row[0], row[1], row[2]) for row in current]
        expected_current = [(uk1, uk2, attribute1) for (uk1, uk2), attribute1 in sorted(t7_expected_current.items())]
        assert (
            actual_current == expected_current
        ), f"Expected current versions {expected_current}, but got {actual_current}"

    #############################################################################################
    # Helper table lifecycle
    #############################################################################################

    def test_failed_run_leaves_no_helper_tables(self, project, parameters, setup_and_teardown):

        """ run fails inside the sequence loop -> no helper tables -> next run succeeds -> no helper tables """

        base = IterativeSnapshot(**parameters)
        existing = set(self._helper_tables(project, parameters))
        run_dbt(["run", "--select", "tag:source"])
        run_sql_with_adapter(project.adapter, base.insert_values(values=[
            ('1', 'U1', 'A', 'A1', 'file1', '2024-01-01'),
            ('1', 'U1', 'B', 'B1', 'file1', '2024-01-01'),
        ]))

        _, log_output = run_dbt_and_capture(
            ["run", "--select", "tag:snapshot", "--vars", "{pytest_fail_on_event: true}"],
            expect_pass=False,
        )
        assert "Materializing source data for" in log_output
        assert set(self._helper_tables(project, parameters)) == existing

        run_dbt(["run", "--select", "tag:snapshot"])
        assert set(self._helper_tables(project, parameters)) == existing

    #############################################################################################
    # Single join key
    #############################################################################################

    def test_key_type_change_still_matches(self, project, parameters, setup_and_teardown):

        """ snapshot with uk1 decimal(10,2) -> source uk1 becomes decimal(10,3) -> change is an update, not a new key

        Same key types use one join key; differing types fall back to one condition per column. """

        source = f"`{parameters['catalog']}`.`{parameters['schema']}`.`{parameters['source_table']}`"
        snapshot = f"`{parameters['catalog']}`.`{parameters['schema']}`.`{parameters['snapshot_table']}`"

        def load_source(uk1_type, row):
            run_sql_with_adapter(project.adapter, f"""
                CREATE OR REPLACE TABLE {source} AS
                SELECT CAST(uk1 AS {uk1_type}) AS uk1, uk2, attribute1, attribute2, file_name,
                       CAST(file_datetime AS timestamp) AS file_datetime
                FROM VALUES {row} AS t(uk1, uk2, attribute1, attribute2, file_name, file_datetime)
            """)

        run_dbt(["run", "--select", "tag:source"])
        load_source("decimal(10,2)", "('1.5', 'U1', 'A', 'A1', 'file1', '2024-01-01')")
        run_dbt(["run", "--select", "tag:snapshot"])

        # Same types: one join key
        load_source("decimal(10,2)", "('1.5', 'U1', 'A', 'A1', 'file2', '2024-01-02')")
        _, same_type_log = run_dbt_and_capture(["--debug", "run", "--select", "tag:snapshot"])
        assert SINGLE_KEY_SEPARATOR in same_type_log and "dbt_unique_key_1" not in same_type_log

        # The snapshot keeps decimal(10,2); as text the key is 1.50 there and 1.500 in the source
        load_source("decimal(10,3)", "('1.5', 'U1', 'B', 'B1', 'file3', '2024-01-03')")
        _, changed_type_log = run_dbt_and_capture(["--debug", "run", "--select", "tag:snapshot"])
        assert "dbt_unique_key_1" in changed_type_log and SINGLE_KEY_SEPARATOR not in changed_type_log

        versions = run_sql_with_adapter(project.adapter, f"""
            SELECT attribute1, dbt_valid_to IS NULL AS is_current, dbt_change_type
            FROM {snapshot}
            ORDER BY dbt_valid_from
        """, fetch="all")
        # A missed key match shows up as a hard delete of the old version plus an insert
        assert [tuple(row) for row in versions] == [("A", False, "update"), ("B", True, "insert")], f"Got {versions}"


class TestPhysicalStagingWithTempViews(_PhysicalStagingSuite):
    """materialize_staging=true, enable_temp_views=true: physical staging must take precedence."""

    enable_temp_views = True


class TestPhysicalStagingWithoutTempViews(_PhysicalStagingSuite):
    """materialize_staging=true, enable_temp_views=false."""

    enable_temp_views = False
