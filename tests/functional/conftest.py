# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Mercedes-Benz Group AG
"""
Pytest configuration for functional tests.
Sets up dbt adapter and environment variables.
"""
import pytest
import os
from pathlib import Path

# Load .env file from project root (for local development)
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).resolve().parents[2] / ".env"
    if env_path.exists():
        load_dotenv(env_path)
except ImportError:
    pass  # python-dotenv not installed, use system env vars

# Register dbt test fixtures
pytest_plugins = ["dbt.tests.fixtures.project"]

# =============================================================================
# CRITICAL: Patch TestProjInfo to prevent schema creation/deletion
# =============================================================================
# We cannot use CREATE SCHEMA in Unity Catalog (no permission) and we must not
# DROP an existing shared schema, so both operations are suppressed entirely.
# This patch must be at module level so it's in place before project_setup
# calls create_test_schema() / drop_test_schema() during fixture setup.

from dbt.tests.fixtures.project import TestProjInfo as _TestProjInfo

_TestProjInfo.create_test_schema = lambda self, schema_name=None: print(
    f"🚫 Skipping schema creation for {schema_name or self.test_schema}"
)
_TestProjInfo.drop_test_schema = lambda self: print(
    f"🚫 Skipping schema drop for {self.test_schema}"
)
# =============================================================================


def pytest_addoption(parser):
    """Add custom command line options."""
    parser.addoption(
        "--debug_mode",
        action="store",
        default="false",
        help="Keep test tables after run (true/false)"
    )


@pytest.fixture(scope="class")
def dbt_profile_target():
    """
    Return the dbt profile target configuration.
    Override with environment variables for CI/CD.
    """
    return {
        "type": "databricks",
        "catalog": os.getenv("DBT_DATABRICKS_CATALOG", "my_catalog"),
        "schema": os.getenv("DBT_DATABRICKS_SCHEMA", "00_metadata"),
        "host": os.getenv("DBT_DATABRICKS_HOST"),
        "http_path": os.getenv("DBT_DATABRICKS_HTTP_PATH"),
        "token": os.getenv("DBT_DATABRICKS_TOKEN"),
        "threads": 4,
    }


@pytest.fixture(scope="class")
def unique_schema():
    """Use the existing shared schema - create/drop are suppressed via class-level patch."""
    return os.getenv("DBT_DATABRICKS_SCHEMA", "00_metadata")


@pytest.fixture(scope="class")
def prefix():
    """Prefix for test tables."""
    return os.getenv("DBT_DEV_TABLE_PREFIX", "pytestoss")


@pytest.fixture(scope="class")
def project_config_update():
    """Update dbt_project.yml for test environment."""
    prefix = os.getenv("DBT_DEV_TABLE_PREFIX", "pytestoss")
    schema = os.getenv("DBT_DATABRICKS_SCHEMA", "00_metadata")
    return {
        "name": "dbt_iterative_snapshot",
        "version": "1.0.0",
        "config-version": 2,
        "profile": "test",
        "model-paths": ["models"],
        "macro-paths": ["macros"],
        "vars": {
            # All vars at root level (as used by macros)
            "dev_table_prefix": prefix,
            "disable_dev_table_prefix": True,  # Disable for dbt model aliases, but keep for explicit table names
            "metadata_schema": schema,
            "enable_data_quality_checks": True,
            "enable_error_logging": True,
            "enable_consistency_checks": True,
            "enable_temp_views": True,
        },
        "dispatch": [
            {"macro_namespace": "dbt_iterative_snapshot", "search_order": ["dbt_iterative_snapshot", "dbt"]},
            {"macro_namespace": "dbt", "search_order": ["dbt_iterative_snapshot", "dbt"]},
        ],
    }


@pytest.fixture(scope="class")
def profiles_config_update():
    """Additional profile configuration."""
    return {}
