# Configuration Reference

## Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `materialized` | string | Must be `'iterative_snapshot'` |
| `unique_key` | string or list | Primary key column(s) for SCD2 tracking |
| `updated_at` | string | Timestamp column from the source system (used for `dbt_valid_from`/`dbt_valid_to`) |
| `sequence_by` | string | Column that identifies the batch and defines processing order (see [FAQ](FAQ.md#what-can-i-use-as-a-sequence_by-value)) |
| `strategy` | string | `'check'` (column comparison) or `'timestamp'` (timestamp-based) |
| `check_cols` | list or `'all'` | Columns to monitor for changes. Required for `strategy='check'`; with `'timestamp'` all columns are used for `changed_attributes` |

```sql
{{ config(
    materialized='iterative_snapshot',
    unique_key='customer_id',
    updated_at='modified_date',
    sequence_by='batch_date',
    strategy='check',
    check_cols=['name', 'email', 'status']
) }}
```

## Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `invalidate_hard_deletes` | `false` | Close records that disappear from a batch (`dbt_change_type = 'delete'`) |
| `enable_data_quality_checks` | `true` | Detect duplicate keys within the same sequence and exclude them from the merge |
| `enable_error_logging` | `true` | Write detected duplicates to the error log table |
| `enable_consistency_checks` | `true` | Validate and repair the SCD2 timeline (`dbt_valid_from`/`dbt_valid_to`) after processing |
| `enable_temp_views` | `true` | Read the source query once into a temporary view instead of once per sequence |
| `enable_schema_evolution` | `true` | Add new source columns to the snapshot table (see [Advanced Usage](ADVANCED_USAGE.md#schema-evolution)) |
| `materialize_staging` | `false` | Build staging as a physical table, for very wide models (see [Troubleshooting](TROUBLESHOOTING.md#stackoverflowerror-during-merge-on-wide-models)) |
| `metadata_table_name` | `iterative_snapshot_metadata` | Name of the metadata table |
| `error_log_table_name` | `iterative_snapshot_error_log` | Name of the error log table |
| `full_refresh` | — | Force (`true`) or prevent (`false`) full refresh for this model, overriding `--full-refresh` |

All `enable_*` options and `materialize_staging` can be set per model in `config()` or project-wide as vars. A model config value takes precedence.

## Project-Level Variables

```yaml
# dbt_project.yml
vars:
  enable_data_quality_checks: true
  enable_error_logging: true
  enable_consistency_checks: true
  enable_temp_views: true
  enable_schema_evolution: true
  materialize_staging: false
  metadata_schema: "dbt_iterative_snapshot_metadata"   # schema for the metadata and error log tables (must exist)
  dev_table_prefix: ""                                 # optional prefix for metadata tables
  disable_dev_table_prefix: false                      # ignore dev_table_prefix, e.g. in production
```

### Metadata Table Location

The metadata and error log tables are created in `<target catalog>.<metadata_schema>`. The schema must already exist.

With `dev_table_prefix` set (and `disable_dev_table_prefix` false), the table names become `<dev_table_prefix>_<target schema>_<table name>`. Use this to give each developer or CI run its own metadata tables.

## Databricks-Specific Options

The snapshot table is created with the standard `dbt-databricks` model configs, for example:

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

The metadata table is always clustered by `(model_name, sequence)`.
