# FAQ

## What's the difference between `updated_at` and `sequence_by`?

- **`updated_at`**: When the record was modified in the source system. Used for `dbt_valid_from`/`dbt_valid_to`.
- **`sequence_by`**: Which batch the record belongs to. Controls processing order.

Example: A record modified on Jan 15 (`updated_at`) might arrive in the Jan 20 batch (`sequence_by = '2024-01-20'`).

## What can I use as a `sequence_by` value?

Any value that identifies a batch and **sorts correctly as a string**, because processed sequences are stored and compared as strings:

- Dates: `batch_date`, `snapshot_date`, `export_date` (ISO format `YYYY-MM-DD`)
- Timestamps: `load_timestamp`, `extracted_at` (ISO format)
- File names or IDs with a sortable, fixed-width pattern, e.g. `export_20240115.csv`, `batch_000042`

Avoid plain integers such as `batch_id = 9, 10` or Kafka offsets: as strings, `'10'` sorts before `'9'`, which breaks out-of-order detection. Zero-pad them in your model instead:

```sql
lpad(cast(batch_id as string), 12, '0') as batch_seq
```

## Does my model need to return all batches or only the new one?

All batches that are still retained in the raw layer. The package compares the batches in your query with the metadata table and processes only the new ones. Returning all retained batches is also what makes out-of-order recovery and full refresh possible.

## What happens to records with duplicate keys in one batch?

With `enable_data_quality_checks=true` (default), all records of a key that appears more than once in the same sequence are excluded from the merge and written to the [error log](OUTPUT_TABLES.md#error-log-data-quality). The rest of the batch is processed normally.

## Does this work with non-Databricks platforms?

Not currently. The package is built for **Databricks** (Delta Lake, Unity Catalog, Databricks SQL) and uses platform-specific features like `MERGE`, `PARSE_JSON`, liquid clustering, and Unity Catalog schema management.
