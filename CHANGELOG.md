# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-06-28

### Added

- **Sequential file processing** for SCD2 snapshots on Databricks
- **Delta Lake native** - Uses MERGE, clustering, and auto-optimize
- **Unity Catalog support** - Full 3-part naming (`catalog.schema.table`)
- **Full refresh with history preservation** - Backs up and restores historical SCD2 rows outside the raw retention window during `--full-refresh`
- **`check_cols='all'` support** - Auto-expands to all columns in the source query
- **Out-of-order sequence handling** - Automatically rebuilds affected sequences when late-arriving files are detected
- **Data quality monitoring**:
  - Corrupt record detection (duplicate unique keys)
  - Error logging to configurable table
  - SCD2 validity column consistency checks
- **Metadata tracking** - Tracks processed sequences for incremental processing
- **Temporary views optimization** - Reduces repeated query compilation
- **Schema evolution** - New source columns are added to the snapshot with their source data type; removed columns are kept for history and reported
- **Merge statistics** - `num_affected_rows`, `num_updated_rows`, `num_deleted_rows`, `num_inserted_rows` from each MERGE are stored in the metadata table (added automatically to existing metadata tables)
- **Event hook** - Overridable `iterative_snapshot_on_event` macro for alerting on duplicate records, out-of-order sequences and schema changes
- **Wide model support** - Flat null-safe change detection for the `check` strategy and optional physical staging tables (`materialize_staging`) to avoid Spark `StackOverflowError` on models with many columns

### Databricks-Specific Features

- Delta Lake MERGE for efficient SCD2 updates
- Liquid clustering on the metadata table
- Auto-optimize table properties
- JSON struct handling for error logging
- Unity Catalog schema creation

### Configuration Options

- `enable_data_quality_checks` - Toggle corrupt record detection (default: true)
- `enable_error_logging` - Toggle error logging (default: true)
- `enable_consistency_checks` - Toggle SCD2 validity validation (default: true)
- `enable_temp_views` - Toggle temporary views for performance (default: true)
- `enable_schema_evolution` - Toggle adding new source columns to the snapshot (default: true)
- `materialize_staging` - Build the per-sequence staging relation as a physical table instead of a temporary view (default: false)

### Supported Strategies

- `check` - Column-based change detection with configurable check_cols (supports `'all'`)
- `timestamp` - Timestamp-based change detection using updated_at column

### Requirements

- dbt 1.9.0 or higher
- Databricks Runtime 15.3+ or Databricks SQL warehouse
- Unity Catalog recommended

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.
