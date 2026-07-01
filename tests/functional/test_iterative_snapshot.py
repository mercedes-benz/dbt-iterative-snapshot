# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Mercedes-Benz Group AG
import pytest
import yaml
import os
from dbt.tests.util import run_dbt, run_sql_with_adapter, write_file, check_relations_equal
from tests.functional.fixtures import IterativeSnapshot
from tests.functional.test_case_0 import *
from tests.functional.test_case_1 import *
from tests.functional.test_case_2 import *
from tests.functional.test_case_3 import *
from tests.functional.test_case_4 import *
from tests.functional.test_case_5 import *
from tests.functional.test_case_6 import *
from pathlib import Path


# run in terminal:
# pytest tests/functional/test_iterative_snapshot.py -s
# If we want to keep the tables after test run, set debug_mode=true:
# pytest tests/functional/test_iterative_snapshot.py -s --debug_mode=true
# To add a new test case:
# step 1: create a new test case python file in the same directory and import it in this code
# step 2: to skip any test case add decorator : @pytest.mark.skip(reason="Skipping this test for now") on top of test function

# environment variables will be populated by conftest.py

PREFIX = os.getenv("DBT_DEV_TABLE_PREFIX", "pytestoss")
USERID = os.getenv("DBT_USER", "pytester")
SOURCE_TABLE_NAME = "pytest_iterative_source"
SNAPSHOT_TABLE_NAME = "pytest_iterative_snapshot"
SNAPSHOT_METADATA_TABLE_NAME = "pytest_iterative_snapshot_metadata"
SNAPSHOT_ERROR_TABLE_NAME = "pytest_iterative_snapshot_error_log"
_PROJECT_ROOT = Path(__file__).resolve().parents[2]
MACRO_FOLDER_PATH = _PROJECT_ROOT / "macros"


class TestIterativeSnapshot():
    
    @pytest.fixture(scope="class")
    def parameters(self, project):
        """Defines parameters for test tables with prefix pattern."""
        schema = project.test_schema

        def full_name(base_name):
            # For CI tests, use clean names to match disabled prefixing
            # Prefixes are disabled via disable_dev_table_prefix=True in conftest.py
            return base_name

        params = {
            'adapter': project.adapter,
            'catalog': project.database,
            'schema': schema,
            'source_table': full_name(SOURCE_TABLE_NAME),
            'snapshot_table': full_name(SNAPSHOT_TABLE_NAME),
            'meta_table': full_name(SNAPSHOT_METADATA_TABLE_NAME),
            'error_table': full_name(SNAPSHOT_ERROR_TABLE_NAME)
        }
        return params

    @pytest.fixture(scope="class")
    def macros(self):
        """Imports macros to test environment."""
        macros = {}

        # Recursively load all .sql files from macros directory
        for file in MACRO_FOLDER_PATH.rglob("*.sql"):
            if not file.name.startswith("."):
                with file.open("r", encoding="utf-8") as f:
                    macros[file.name] = f.read()

        return macros
    
    @pytest.fixture(scope="class")
    def models(self):
        """ import models to test environment dbt project """
        return {
            f"{SNAPSHOT_TABLE_NAME}.sql": IterativeSnapshot.create_snapshot_dbt_model(SOURCE_TABLE_NAME,SNAPSHOT_METADATA_TABLE_NAME,SNAPSHOT_ERROR_TABLE_NAME),
            f"{SOURCE_TABLE_NAME}.sql": IterativeSnapshot.create_source_dbt_model(),
            
        }

    @pytest.fixture
    def setup_and_teardown(self,request, project, parameters):
        """
        Fixture for setting up and tearing down test resources.
        """
        base = IterativeSnapshot(**parameters)

        # Setup
        run_sql_with_adapter(project.adapter, base.drop_table(table_name=parameters['source_table']))
        run_sql_with_adapter(project.adapter, base.drop_table(table_name=parameters['snapshot_table']))
        run_sql_with_adapter(project.adapter, base.drop_table(table_name=parameters['meta_table']))
        run_sql_with_adapter(project.adapter, base.drop_table(table_name=parameters['error_table']))
        yield  # Test execution happens here

        # Teardown
        if request.config.getoption("--debug_mode") == 'false': # default is false
            run_sql_with_adapter(project.adapter, base.drop_table(table_name=parameters['source_table']))
            run_sql_with_adapter(project.adapter, base.drop_table(table_name=parameters['snapshot_table']))
            run_sql_with_adapter(project.adapter, base.drop_table(table_name=parameters['meta_table']))
            run_sql_with_adapter(project.adapter, base.drop_table(table_name=parameters['error_table']))


    #############################################################################################
    # TEST CASE - 0 - regular snapshot load
    #############################################################################################

    #@pytest.mark.skip(reason="Skipping this test for now")
    def test_case_0(self, project, parameters,setup_and_teardown):
        
        """ create source -> insert batch 1 -> run snapshot -> insert batch 2 -> run snapshot """
        
        base = IterativeSnapshot(**parameters)
        
        run_dbt(["run", "--select", "tag:source"])

        run_sql_with_adapter(project.adapter, base.insert_values(values=t0_insert_batch_1))
        
        run_dbt(["run","--select", "tag:snapshot"])
        
        run_sql_with_adapter(project.adapter,base.insert_values(values=t0_insert_batch_2)) 
        
        run_dbt(["run","--select", "tag:snapshot"])

        expected_result = run_sql_with_adapter(project.adapter,base.generate_expected_sql(values=t0_expected_result_1),fetch="all" )
        
        actual_result = run_sql_with_adapter(project.adapter, base.generate_actual_sql(),fetch="all")
                
        assert (
            expected_result == actual_result
        ), f"Expected {expected_result}, but got {actual_result}"



    # #############################################################################################
    # # TEST CASE - 1 - regular snapshot load with new file only
    # #############################################################################################

    #@pytest.mark.skip(reason="Skipping this test for now")
    def test_case_1(self, project, parameters,setup_and_teardown):
        
        """ create source -> insert batch 1 -> run snapshot -> truncate source -> insert batch 2 -> run snapshot """
        
        base = IterativeSnapshot(**parameters)
        
        run_dbt(["run", "--select", "tag:source"])
        
        run_sql_with_adapter(project.adapter, base.insert_values(values=t1_insert_batch_1))
        
        run_dbt(["run","--select", "tag:snapshot"])
        
        run_sql_with_adapter(project.adapter, base.truncate_table(table_name=parameters['source_table']))
        
        
        run_sql_with_adapter(project.adapter, base.insert_values(values=t1_insert_batch_2))
        
        run_dbt(["run","--select", "tag:snapshot"])

        expected_result = run_sql_with_adapter(project.adapter,base.generate_expected_sql(values=t1_expected_result_1),fetch="all" )
        
        actual_result = run_sql_with_adapter(project.adapter, base.generate_actual_sql(),fetch="all")
                
        assert (
            expected_result == actual_result
        ), f"Expected {expected_result}, but got {actual_result}"



    # #############################################################################################
    # # TEST CASE - 2 -  load multiple files at once  
    # #############################################################################################

    #@pytest.mark.skip(reason="Skipping this test for now")
    def test_case_2(self, project, parameters,setup_and_teardown):
        
        """ create source -> insert batch 1 -> run snapshot  """
        
        base = IterativeSnapshot(**parameters)
        
        run_dbt(["run", "--select", "tag:source"])
        
        run_sql_with_adapter(project.adapter, base.insert_values(values=t2_insert_batch_1))
        
        run_dbt(["run","--select", "tag:snapshot"])

        expected_result = run_sql_with_adapter(project.adapter,base.generate_expected_sql(values=t2_expected_result_1),fetch="all" )
        
        actual_result = run_sql_with_adapter(project.adapter, base.generate_actual_sql(),fetch="all")
                
        assert (
            expected_result == actual_result
        ), f"Expected {expected_result}, but got {actual_result}"



    # #############################################################################################
    # # TEST CASE - 3 - load multiple files at once - same change tracking value 
    # #############################################################################################

    #@pytest.mark.skip(reason="Skipping this test for now")
    def test_case_3(self, project, parameters,setup_and_teardown):
        
        """ create source -> insert batch 1 -> run snapshot  """
        
        base = IterativeSnapshot(**parameters)
        
        run_dbt(["run", "--select", "tag:source"])
        
        run_sql_with_adapter(project.adapter, base.insert_values(values=t3_insert_batch_1))
        
        run_dbt(["run","--select", "tag:snapshot"])

        expected_result = run_sql_with_adapter(project.adapter,base.generate_expected_sql(values=t3_expected_result_1),fetch="all" )
        
        actual_result = run_sql_with_adapter(project.adapter, base.generate_actual_sql(),fetch="all")
                
        assert (
            expected_result == actual_result
        ), f"Expected {expected_result}, but got {actual_result}"

    #############################################################################################
    # TEST CASE - 4 - handle back fill with older files
    #############################################################################################

    #@pytest.mark.skip(reason="Skipping this test for now")
    def test_case_4(self, project, parameters,setup_and_teardown):
        
        """ create source -> insert batch 1 -> run snapshot -> insert batch 2 -> run snapshot """
        
        base = IterativeSnapshot(**parameters)
        
        run_dbt(["run", "--select", "tag:source"])

        run_sql_with_adapter(project.adapter, base.insert_values(values=t4_insert_batch_1))
        
        run_dbt(["run","--select", "tag:snapshot"])
        
        run_sql_with_adapter(project.adapter,base.insert_values(values=t4_insert_batch_2)) 
        
        run_dbt(["run","--select", "tag:snapshot"])

        expected_result = run_sql_with_adapter(project.adapter,base.generate_expected_sql(values=t4_expected_result_1),fetch="all" )
        
        actual_result = run_sql_with_adapter(project.adapter, base.generate_actual_sql(),fetch="all")
                
        assert (
            expected_result == actual_result
        ), f"Expected {expected_result}, but got {actual_result}"


    # #############################################################################################
    # # TEST CASE - 5 - Loading new records after retention period
    # #############################################################################################

    #@pytest.mark.skip(reason="Skipping this test for now")
    def test_case_5(self, project, parameters,setup_and_teardown):
        
        """ create source -> insert batch 1 -> run snapshot ->  insert batch 2 -> run snapshot -> truncate source -> insert batch 3 -> run snapshot """
        
        base = IterativeSnapshot(**parameters)
        
        run_dbt(["run", "--select", "tag:source"])
        
        run_sql_with_adapter(project.adapter, base.insert_values(values=t5_insert_batch_1))
        
        run_dbt(["run","--select", "tag:snapshot"])
        
        
        run_sql_with_adapter(project.adapter, base.insert_values(values=t5_insert_batch_2))
        
        run_dbt(["run","--select", "tag:snapshot"])

        run_sql_with_adapter(project.adapter, base.truncate_table(table_name=parameters['source_table']))

        run_sql_with_adapter(project.adapter, base.insert_values(values=t5_insert_batch_3))
        
        run_dbt(["run","--select", "tag:snapshot"])

        expected_result = run_sql_with_adapter(project.adapter,base.generate_expected_sql(values=t5_expected_result_1),fetch="all" )
        
        actual_result = run_sql_with_adapter(project.adapter, base.generate_actual_sql(),fetch="all")
                
        assert (
            expected_result == actual_result
        ), f"Expected {expected_result}, but got {actual_result}"


    #############################################################################################
    # TEST CASE - 6 - 'backing_table' scenario: Out of order file older than 60 days
    #############################################################################################

    #@pytest.mark.skip(reason="Skipping this test for now")
    def test_case_6(self, project, parameters,setup_and_teardown):
        
        """ create source -> insert batch 1 -> run snapshot -> insert batch 2 -> run snapshot """
        
        base = IterativeSnapshot(**parameters)
        
        run_dbt(["run", "--select", "tag:source"])

        run_sql_with_adapter(project.adapter, base.insert_values(values=t6_insert_batch_1))
        
        run_dbt(["run","--select", "tag:snapshot"])
        
        run_sql_with_adapter(project.adapter,base.insert_values(values=t6_insert_batch_2)) 
        
        run_dbt(["run","--select", "tag:snapshot"])

        expected_result = run_sql_with_adapter(project.adapter,base.generate_expected_sql(values=t6_expected_result_1),fetch="all" )
        
        actual_result = run_sql_with_adapter(project.adapter, base.generate_actual_sql(),fetch="all")
                
        assert (
            expected_result == actual_result
        ), f"Expected {expected_result}, but got {actual_result}"

