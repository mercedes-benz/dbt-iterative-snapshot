# Functional Tests for dbt-iterative-snapshot

This folder contains pytest-based functional tests that validate the iterative snapshot materialization against a real Databricks environment.

## Test Cases

| Test Case | Description | Key Validation |
|-----------|-------------|----------------|
| `test_case_0_regular_load` | Load file1, then file2 | Basic SCD2: insert, update, delete |
| `test_case_1_incremental_load` | Load file1, truncate source, load file2 | Metadata tracking preserves history |
| `test_case_2_multiple_files` | Load 3 files at once | Sequential processing by `sequence_by` |
| `test_case_3_out_of_order` | Load file2 first, then file1 (late arrival) | **Out-of-order detection and reprocessing** |
| `test_case_4_hard_deletes` | Record missing in file2 | Hard delete tracking |
| `test_case_5_reappearing_record` | Record deleted then reappears | Delete + reinsert history |

## Running Tests

### Prerequisites

Set environment variables in `.env` file at project root:

```bash
DBT_DATABRICKS_HOST=your-workspace.azuredatabricks.net
DBT_DATABRICKS_HTTP_PATH=/sql/1.0/warehouses/your_warehouse_id
DBT_DATABRICKS_TOKEN=your_token
DBT_DATABRICKS_CATALOG=your_catalog
DBT_DATABRICKS_SCHEMA=00_metadata
DBT_DEV_TABLE_PREFIX=pytestoss
```

### Run All Functional Tests

```bash
python run_tests.py --func-only
```

### Run Specific Test

```bash
pytest tests/functional/test_iterative_snapshot.py::TestIterativeSnapshot::test_case_3_out_of_order -s
```

### Debug Mode (Keep Tables)

```bash
pytest tests/functional/test_iterative_snapshot.py -s --debug_mode=true
```

Tables will NOT be dropped after test run, allowing you to inspect results.

## Adding a New Test Case

### Step 1: Create Test Data File

Create `test_case_N_description.py` with input batches and expected results:

```python
"""
Test Case N: Brief description of what this tests
"""

# Input data: (uk1, uk2, attribute1, attribute2, file_name, file_datetime)
input_batch_1 = [
    ('1', 'U1', 'A', 'A1', 'file1', '2024-01-01'),
    ('2', 'U2', 'B', 'B1', 'file1', '2024-01-01'),
]

input_batch_2 = [
    ('1', 'U1', 'A', 'A2', 'file2', '2024-01-02'),  # Updated
    ('2', 'U2', 'B', 'B1', 'file2', '2024-01-02'),  # No change
]

# Expected result: (uk1, uk2, attr1, attr2, file_name, file_datetime, valid_from, valid_to, change_type)
expected_result = [
    ('1', 'U1', 'A', 'A1', 'file1', '2024-01-01 00:00:00', '2024-01-01 00:00:00', '2024-01-02', 'insert'),
    ('1', 'U1', 'A', 'A2', 'file2', '2024-01-02 00:00:00', '2024-01-02 00:00:00', None, 'update'),
    ('2', 'U2', 'B', 'B1', 'file1', '2024-01-01 00:00:00', '2024-01-01 00:00:00', None, 'insert'),
]
```

**Data Format Notes:**
- `valid_to`: `None` for current records, date string for closed records
- `change_type`: `"insert"`, `"update"`, or `"delete"`
- Results are ordered by `uk1, file_datetime`

### Step 2: Import in test_iterative_snapshot.py

Add imports at the top of the file:

```python
from tests.functional.test_case_N_description import (
    input_batch_1 as tN_batch_1,
    input_batch_2 as tN_batch_2,
    expected_result as tN_expected,
)
```

### Step 3: Add Test Method

Add a new test method to the `TestIterativeSnapshot` class:

```python
#############################################################################################
# TEST CASE N - Description
#############################################################################################
def test_case_N_description(self, project, parameters, setup_and_teardown):
    """Brief description of the test scenario"""
    base = IterativeSnapshot(**parameters)

    # Create source table
    run_dbt(["run", "--select", "tag:source"])
    
    # Insert batch 1
    run_sql_with_adapter(project.adapter, base.insert_values(values=tN_batch_1))
    
    # Run snapshot
    run_dbt(["run", "--select", "tag:snapshot"])
    
    # Insert batch 2 (if applicable)
    run_sql_with_adapter(project.adapter, base.insert_values(values=tN_batch_2))
    
    # Run snapshot again
    run_dbt(["run", "--select", "tag:snapshot"])

    # Validate results
    expected = run_sql_with_adapter(project.adapter, base.generate_expected_sql(values=tN_expected), fetch="all")
    actual = run_sql_with_adapter(project.adapter, base.generate_actual_sql(), fetch="all")

    assert expected == actual, f"Expected {expected}, but got {actual}"
```

### Step 4: Run Your Test

```bash
# Run only your new test
pytest tests/functional/test_iterative_snapshot.py::TestIterativeSnapshot::test_case_N_description -s

# Run with debug mode to inspect tables
pytest tests/functional/test_iterative_snapshot.py::TestIterativeSnapshot::test_case_N_description -s --debug_mode=true
```

### Step 5: Skip Test (Optional)

To temporarily skip a test, add the decorator:

```python
@pytest.mark.skip(reason="Skipping this test for now")
def test_case_N_description(self, project, parameters, setup_and_teardown):
    ...
```

## Test Patterns

### Pattern: Truncate Source Between Batches

Used when simulating incremental file loads where old files are removed:

```python
run_sql_with_adapter(project.adapter, base.truncate_table(parameters['source_table']))
run_sql_with_adapter(project.adapter, base.insert_values(values=tN_batch_2))
```

### Pattern: Out-of-Order Processing

Load newer file first, then older file arrives late:

```python
# Batch 1 contains file2 (newer)
run_sql_with_adapter(project.adapter, base.insert_values(values=batch_file2))
run_dbt(["run", "--select", "tag:snapshot"])

# Batch 2 contains file1 (older - late arrival)
run_sql_with_adapter(project.adapter, base.insert_values(values=batch_file1))
run_dbt(["run", "--select", "tag:snapshot"])
```

### Pattern: Multiple Batches

For complex scenarios with 3+ batches:

```python
run_sql_with_adapter(project.adapter, base.insert_values(values=tN_batch_1))
run_dbt(["run", "--select", "tag:snapshot"])

run_sql_with_adapter(project.adapter, base.insert_values(values=tN_batch_2))
run_dbt(["run", "--select", "tag:snapshot"])

run_sql_with_adapter(project.adapter, base.truncate_table(parameters['source_table']))
run_sql_with_adapter(project.adapter, base.insert_values(values=tN_batch_3))
run_dbt(["run", "--select", "tag:snapshot"])
```

## File Structure

```
tests/functional/
├── README.md                          # This file
├── conftest.py                        # Pytest configuration & fixtures
├── fixtures.py                        # SQL generation helpers
├── test_iterative_snapshot.py         # Main test orchestrator
├── test_case_0_regular_load.py        # Test data for case 0
├── test_case_1_incremental_load.py    # Test data for case 1
├── test_case_2_multiple_files.py      # Test data for case 2
├── test_case_3_out_of_order.py        # Test data for case 3 (KEY TEST)
├── test_case_4_hard_deletes.py        # Test data for case 4
└── test_case_5_reappearing_record.py  # Test data for case 5
```

## Troubleshooting

### "TABLE_OR_VIEW_NOT_FOUND" Error

Model tables use their plain names (e.g. `pytest_iterative_source`) in `DBT_DATABRICKS_SCHEMA`. Verify:
- `DBT_DATABRICKS_CATALOG` and `DBT_DATABRICKS_SCHEMA` point to an existing schema you can write to
- No other test run (local or CI) is using the same schema at the same time, since runs share fixed table names

### "Required var not found" Error

Ensure all vars are set at root level in `conftest.py`:
- `dev_table_prefix`
- `metadata_schema`

### Tests Fail with Permission Errors

The schema must already exist - tests don't create schemas. Use a schema you have write access to (e.g., `00_metadata`).
