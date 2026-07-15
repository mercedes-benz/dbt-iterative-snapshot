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

**Solution**: Build the staging relation as a physical table so it is optimized once, separately from the MERGE:
```sql
{{ config(materialize_staging=true) }}
```
The table is created in the model's schema and dropped at the end of a successful run. If a run fails midway, drop leftover `<model>__dbt_tmp_*` tables manually.

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