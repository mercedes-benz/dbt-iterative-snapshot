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

### Databricks-Specific Features

- Delta Lake MERGE for efficient SCD2 updates
- Liquid clustering on sequence columns
- Auto-optimize table properties
- JSON struct handling for error logging
- Unity Catalog schema creation

### Configuration Options

- `enable_data_quality_checks` - Toggle corrupt record detection (default: true)
- `enable_metadata_tracking` - Toggle processing metrics tracking (default: true)
- `enable_error_logging` - Toggle error logging (default: true)
- `enable_consistency_checks` - Toggle SCD2 validity validation (default: true)
- `enable_temp_views` - Toggle temporary views for performance (default: true)
- `enable_clustering` - Toggle Delta Lake clustering (default: true)

### Supported Strategies

- `check` - Column-based change detection with configurable check_cols (supports `'all'`)
- `timestamp` - Timestamp-based change detection using updated_at column

### Requirements

- dbt 1.6.0 or higher
- Databricks Runtime 10.4+
- Unity Catalog recommended

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.
