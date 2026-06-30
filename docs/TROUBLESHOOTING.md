# Troubleshooting

## Common Issues

### "Out of order sequence detected"
**Cause**: Files processed in wrong chronological order
**Solution**: Check your `sequence_by` column represents proper chronological order
```sql
-- Good: dates or incrementing numbers  
sequence_by='file_date'  -- 2024-01-01, 2024-01-02, 2024-01-03
sequence_by='batch_id'   -- 001, 002, 003

-- Bad: random or unordered values
sequence_by='random_uuid' -- xyz-123, abc-456, def-789
```

### "Materialization not supported for this adapter"
**Cause**: Missing adapter-specific implementation
**Solution**: Check [supported adapters](../README.md#-supported-adapters) or request support

### "Performance is slow"
**Solutions**:
```yaml
# dbt_project.yml
vars:
  batch_processing_mode: aggressive  # Larger batches
  enable_data_quality_checks: false  # Skip validation
```

### "Data quality issues detected"
**Check error log**:
```sql
SELECT * FROM your_metadata_schema.iterative_snapshot_error_log
WHERE model_name = 'your_model_name'
ORDER BY inserted_at DESC;
```

### "Schema not found errors"
**Solution**: Ensure metadata schema exists or let package create it automatically

## Debug Mode

Enable verbose logging:
```yaml
# dbt_project.yml
vars:
  debug_mode: true
```

## Getting Help

1. Check error logs in metadata tables
2. Enable debug mode for detailed logging  
3. Review configuration against [examples](../README.md)
4. Open GitHub issue with error details