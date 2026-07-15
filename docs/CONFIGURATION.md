# Configuration Reference

Quick reference for all configuration options.

## Required Configuration

```sql
{{ config(
    materialized='iterative_snapshot',
    unique_key='user_id',              -- Primary key (string or list)
    updated_at='modified_timestamp',   -- Source system timestamp
    sequence_by='file_date',           -- Sequential ordering column
    strategy='check',                  -- or 'timestamp'
    check_cols=['status', 'email']     -- Columns to monitor for changes (or 'all')
) }}
```

## Optional Configuration

### Data Quality & Tracking

```sql
{{ config(
    invalidate_hard_deletes=true,      -- Track deletions (default: false)
    enable_data_quality_checks=false,  -- Skip duplicate key detection (default: true)
    enable_consistency_checks=false,   -- Skip SCD2 validation (default: true)
) }}
```

### Global Variables (dbt_project.yml)

```yaml
vars:
  dbt_iterative_snapshot:
    enable_data_quality_checks: true    # Detect duplicate keys within a batch
    enable_error_logging: true          # Log data quality issues to error table
    enable_consistency_checks: true     # Validate SCD2 timeline after each sequence
    enable_temp_views: true             # Use temporary views for performance
    enable_clustering: true             # Delta Lake liquid clustering
    metadata_schema: "dbt_iterative_snapshot_metadata"  # Schema for metadata/error tables
    dev_table_prefix: ""                # Optional prefix for dev/test isolation
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
