# Integration Tests for dbt-iterative-snapshot

This folder contains integration tests to validate the `dbt-iterative-snapshot` package.

## Quick Start

```bash
cd integration_tests

# Set environment variables
export DBT_DATABRICKS_HOST="your-workspace.azuredatabricks.net"
export DBT_DATABRICKS_HTTP_PATH="/sql/1.0/warehouses/your_warehouse_id"
export DBT_DATABRICKS_TOKEN="your_token"
export DBT_DATABRICKS_CATALOG="your_catalog"

# 1. Install dependencies (including the parent package)
dbt deps --profiles-dir .

# 2. Load test seed data
dbt seed --profiles-dir . --target dev

# 3. Run all integration test models
dbt run --profiles-dir . --target dev

# 4. Run data tests to validate SCD2 correctness
dbt test --profiles-dir . --target dev
```

## Test Models

| Model | Strategy | Description |
|-------|----------|-------------|
| `test_iterative_snapshot_basic` | check | Composite unique key `['uk1', 'uk2']`, column-based change detection |
| `test_iterative_snapshot_timestamp_strategy` | timestamp | Single unique key, timestamp-based change detection |
| `test_out_of_order_data` | check | Simulates late-arriving files to test reprocessing |

## Test Data

### `sample_file_data.csv`
Simulates 3 daily file exports with user status changes:
- `file_001.csv` - Initial load (users 1, 2, 3)
- `file_002.csv` - Updates (user 2 inactive, user 4 joins)
- `file_003.csv` - More changes (user 2 reactivated, user 5 joins)

### `edge_case_data.csv`
Tests composite unique keys (`uk1`, `uk2`) with attribute changes across 3 files.

## Validation Tests

| Test | What it validates |
|------|-------------------|
| `test_scd2_validity_periods.sql` | No gaps/overlaps in `dbt_valid_from`/`dbt_valid_to` |
| `test_metadata_table_creation.sql` | Metadata tracking table exists and has records |
| `test_error_log_functionality.sql` | Error log table captures data quality issues |

## Expected Results

After running all models, verify:

```sql
-- Check SCD2 output has correct structure
SELECT 
    uk1, uk2, attribute1, attribute2,
    dbt_valid_from, dbt_valid_to, dbt_change_type
FROM <your_catalog>.iterative_snapshot_integration_tests.test_iterative_snapshot_basic
ORDER BY uk1, uk2, dbt_valid_from;

-- Check metadata tracking
SELECT * 
FROM <your_catalog>.integration_test_metadata.iterative_snapshot_metadata
ORDER BY model_name, sequence_value;
```

## Running Individual Tests

```bash
# Run just the basic test
dbt run --select test_iterative_snapshot_basic --profiles-dir . --target dev

# Run with full refresh (reprocess all sequences)
dbt run --select test_iterative_snapshot_basic --profiles-dir . --target dev --full-refresh

# Run data tests only
dbt test --select test_iterative_snapshot_basic --profiles-dir . --target dev
```

## CI Configuration

For GitHub Actions, use the `ci` target which creates isolated schemas per run:

```bash
dbt seed --profiles-dir . --target ci
dbt run --profiles-dir . --target ci
dbt test --profiles-dir . --target ci
```

Environment variables needed:
- `DBT_DATABRICKS_HOST`
- `DBT_DATABRICKS_HTTP_PATH`
- `DBT_DATABRICKS_TOKEN`
- `DBT_DATABRICKS_CATALOG`

## Troubleshooting

### "Relation does not exist" for seeds
Run `dbt seed` first to load the test data.

### "No sequences to process"
The metadata table shows all files as processed. Use `--full-refresh` to reprocess.

### Permission errors
Ensure your token has CREATE TABLE permissions on the target schema.
