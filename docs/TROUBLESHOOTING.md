# Troubleshooting

## Common Issues

### "Out of order sequence detected"

**Cause**: A batch arrived with a `sequence_by` value earlier than already-processed sequences.

**What happens**: The package automatically backs up affected records, reprocesses in correct order, and restores SCD2 history. This is expected behavior — no action needed.

**If unexpected**: Check your `sequence_by` column represents proper chronological order:
```sql
-- Good: dates or incrementing numbers
sequence_by='file_date'  -- 2024-01-01, 2024-01-02, 2024-01-03
sequence_by='batch_id'   -- 001, 002, 003

-- Bad: random or unordered values
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

### "Data quality issues detected"

**Check error log**:
```sql
SELECT * FROM your_metadata_schema.iterative_snapshot_error_log
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
2. Review configuration against [docs/CONFIGURATION.md](CONFIGURATION.md)
3. Open a [GitHub issue](https://github.com/mercedes-benz/dbt-iterative-snapshot/issues) with error details