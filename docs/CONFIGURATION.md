# Configuration Reference

Quick reference for advanced configuration options.

## Required Configuration
```sql
{{ config(
    materialized='iterative_snapshot',
    unique_key='user_id',              -- Primary key
    updated_at='modified_timestamp',   -- Source system timestamp
    sequence_by='file_date',           -- Sequential ordering column
    strategy='check',                  -- or 'timestamp'
    check_cols=['status', 'email']     -- Columns to monitor for changes
) }}
```

## Optional Configuration

### Performance Tuning
```sql
{{ config(
    batch_size=50,                     -- Records per batch (default: auto)
    performance_profile='balanced'      -- fast/balanced/thorough
) }}
```

### Data Quality
```sql
{{ config(
    invalidate_hard_deletes=true,      -- Track deletions (default: false)
) }}
```

### Global Variables (dbt_project.yml)
```yaml
vars:
  dbt_iterative_snapshot:
    enable_data_quality_checks: true    # Detect corrupted records
    enable_clustering: true             # Delta Lake optimization
    debug_mode: false                   # Verbose logging
    metadata_schema: "00_metadata"      # Metadata storage location
```

## Databricks-Specific Options

### Delta Lake Table Properties
```sql
{{ config(
    tblproperties={
        'delta.autoOptimize.optimizeWrite': 'true',
        'delta.autoOptimize.autoCompact': 'true'
    }
) }}
```

### Liquid Clustering
```sql
{{ config(
    liquid_clustered_by=['sequence_column', 'unique_key']
) }}
```

For complete examples, see the [main README](../README.md).
