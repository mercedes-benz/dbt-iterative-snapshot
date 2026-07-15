# Output Tables

## Snapshot Table (your model)

Your source columns plus these SCD2 columns:

| Column | Description |
|--------|-------------|
| `dbt_scd_id` | Unique hash for each record version |
| `dbt_valid_from` | When this version became active |
| `dbt_valid_to` | When it was superseded (`NULL` = current record) |
| `dbt_updated_at` | Source system timestamp |
| `dbt_change_type` | `insert` on current rows; on closed rows the reason they were closed: `update` or `delete` |
| `changed_attributes` | JSON array of the columns that changed (set on rows closed by an `update`) |
| `inserted_at` | When the row was written to the snapshot |

## Metadata Table (audit trail)

`<catalog>.<metadata_schema>.iterative_snapshot_metadata`, one row per processed sequence:

| Column | Description |
|--------|-------------|
| `model_name` | Snapshot model name |
| `sequence` | The batch/sequence value processed |
| `invocation_id` | dbt run ID |
| `node_id` | dbt node ID of the model |
| `run_started_at` | When the dbt run started |
| `inserted_at` | When the sequence was logged |
| `processed_by` | User or service principal that ran it |
| `num_affected_rows` | Rows affected by the MERGE for this sequence |
| `num_inserted_rows` / `num_updated_rows` / `num_deleted_rows` | MERGE breakdown; distinguishes "ran" from "ran and wrote rows" |

Metadata tables created by earlier versions get the `num_*_rows` columns added automatically.

## Error Log (data quality)

`<catalog>.<metadata_schema>.iterative_snapshot_error_log`, records excluded because of duplicate unique keys within one sequence:

| Column | Description |
|--------|-------------|
| `model_name` | Snapshot model name |
| `sequence` | Batch with the issue |
| `unique_key` | The duplicate key value |
| `corrupted_record` | Full record data (JSON) |
| `invocation_id`, `node_id`, `run_started_at`, `inserted_at`, `processed_by` | Run context |

## Querying Examples

```sql
-- Current records
SELECT * FROM my_snapshot WHERE dbt_valid_to IS NULL;

-- Full history for one entity
SELECT * FROM my_snapshot
WHERE customer_id = 123
ORDER BY dbt_valid_from;

-- Which batches have been processed, and did they change anything?
SELECT sequence, inserted_at, num_inserted_rows, num_updated_rows
FROM my_catalog.dbt_iterative_snapshot_metadata.iterative_snapshot_metadata
WHERE model_name = 'my_snapshot'
ORDER BY sequence;

-- Any data quality issues?
SELECT * FROM my_catalog.dbt_iterative_snapshot_metadata.iterative_snapshot_error_log
WHERE model_name = 'my_snapshot'
ORDER BY inserted_at DESC;
```
