# Troubleshooting

## Quick Reference

| Issue | Cause | Solution |
|-------|-------|----------|
| "No object to process" | All sequences already processed | Check for new data or use `--full-refresh` |
| Duplicate key errors in log | Multiple records with same key in one batch | Clean source data or adjust `unique_key` |
| Out-of-order reprocessing slow | Rebuilding many sequences | Ensure batches arrive in order when possible |
| Metadata table not found | Metadata schema doesn't exist | Create the schema set in `metadata_schema` |
| `StackOverflowError` on MERGE | Very wide model | Set `materialize_staging=true` |

## Common Issues

### "Out of order sequence detected"

**Cause**: A batch arrived with a `sequence_by` value earlier than already-processed sequences.

**What happens**: The package deletes the snapshot rows of the affected later batches and reprocesses all of them from raw in the correct order (see [How It Works](HOW_IT_WORKS.md#out-of-order-handling)). This is expected behavior, and no action is needed.

**If unexpected**: Check that your `sequence_by` column sorts in chronological order **as a string**:
```sql
-- Good: ISO dates or zero-padded IDs
sequence_by='file_date'  -- 2024-01-01, 2024-01-02, 2024-01-03
sequence_by='batch_id'   -- 001, 002, 003

-- Bad: unpadded integers or unordered values
sequence_by='batch_id'    -- 9, 10, 11  ('10' sorts before '9')
sequence_by='random_uuid' -- xyz-123, abc-456, def-789
```

### "No object to process"

**Cause**: All sequences in the source data have already been processed.

**Solution**: Check for new data in your source, or use `--full-refresh` to reprocess everything.

### "Performance is slow"

**Solutions**: Disable checks you don't need:
```yaml
# dbt_project.yml
vars:
  dbt_iterative_snapshot:
    enable_data_quality_checks: false   # Skip duplicate key detection
    enable_consistency_checks: false    # Skip SCD2 validation
```

### "StackOverflowError" during MERGE on wide models

**Cause**: With hundreds of `check_cols`, Spark's optimizer recurses too deeply while planning the MERGE against the staging view.

**Solution**: Use physical tables so each step is optimized once, separately from the MERGE:
```sql
{{ config(materialize_staging=true) }}
```
This writes the source rows for all pending sequences to one table (read by every iteration instead of re-running the model query) and builds each staging relation as a table.

With a multi-column `unique_key`, the staging select then joins on one key built from all key columns instead of one condition per column. The failure is more likely on a freshly started warehouse, so a model that passes on a warm one can still fail after a restart.

**Limitation**: the single key compares the key columns as text, which only matches like a per-column comparison when both sides have the same type. If a key column's type differs between the source and the snapshot (for example `decimal(10,3)` against `decimal(10,2)`), the model keeps one condition per column and can still hit the error. Align the types, for example by casting the key column in the model to the snapshot's type, if it does.

The tables are created in the model's schema and dropped at the end of the run. If a model fails, the package's `on-run-end` hook drops the tables of that run. If the dbt process is killed before the hook runs, drop leftover `<model>__src_*` and `<model>__dbt_tmp_*` tables manually, once no other run of that model is active.

### "Data quality issues detected"

**Check error log**:
```sql
SELECT * FROM your_catalog.dbt_iterative_snapshot_metadata.iterative_snapshot_error_log
WHERE model_name = 'your_model_name'
ORDER BY inserted_at DESC;
```

This typically means duplicate unique keys were found within a single batch. Clean your source data or adjust `unique_key` to be truly unique per batch.

### "Schema not found errors"

**Cause**: The metadata schema doesn't exist yet.

**Solution**: Create it manually or ensure your service principal has `CREATE SCHEMA` permissions:
```sql
CREATE SCHEMA IF NOT EXISTS your_catalog.dbt_iterative_snapshot_metadata;
```

## Getting Help

1. Check error logs in metadata tables
2. Review your configuration against the [Configuration Reference](CONFIGURATION.md) and the [FAQ](FAQ.md)
3. Open a [GitHub issue](https://github.com/mercedes-benz/dbt-iterative-snapshot/issues) with error details