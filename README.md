# dbt-iterative-snapshot

> **SCD2 snapshots that process data batches in sequence, even when they arrive out of order.**

[![dbt Version](https://img.shields.io/badge/dbt-1.9%2B-orange.svg)](https://getdbt.com)
[![Databricks](https://img.shields.io/badge/Databricks-Unity%20Catalog-orange.svg)](https://databricks.com)
[![License](https://img.shields.io/badge/License-MIT-brightgreen.svg)](LICENSE)

> **Note**: This is an open source project by Mercedes-Benz Group AG. Source code has been tested solely for our own use cases, which might differ from yours.

Standard dbt snapshots assume one live source table queried once per run. When your data arrives as **sequential batches** (daily file exports, CDC streams, API syncs) and a batch arrives late, the SCD2 history gets corrupted.

`iterative_snapshot` is a dbt materialization for **Databricks** that processes each batch in the order defined by a `sequence_by` column, detects late batches and reprocesses them automatically, and keeps a correct SCD2 history.

## Features

- **Sequence-based processing**: batches are applied in `sequence_by` order, not arrival order
- **Out-of-order self-healing**: late batches trigger an automatic, ordered reprocessing
- **Change tracking**: `changed_attributes` lists exactly which columns changed
- **Data quality**: duplicate keys within a batch are excluded and logged to an error table
- **Audit trail**: every processed batch is recorded with its MERGE row counts
- **Schema evolution**: new source columns are added to the snapshot automatically
- **Full refresh with history preservation**: rebuild without losing history outside the raw retention window

## Quick Start

### 1. Install

```yaml
# packages.yml
packages:
  - git: "https://github.com/mercedes-benz/dbt-iterative-snapshot.git"
    revision: main   # replace with a release tag, e.g. v1.0.0, once available
```

```bash
dbt deps
```

### 2. Create a snapshot model

```sql
-- models/customer_history.sql
{{ config(
    materialized='iterative_snapshot',
    unique_key='customer_id',
    updated_at='modified_date',
    sequence_by='batch_date',
    strategy='check',
    check_cols=['name', 'email', 'status']
) }}

SELECT customer_id, name, email, status, modified_date, batch_date
FROM {{ source('raw', 'customer_updates') }}
```

> **Important**: The `SELECT` must return **all batches still retained in the raw layer** (typically an append-only table of every loaded file), not only the latest one. Each run processes only the batches it hasn't seen yet.

### 3. Run

```bash
dbt run --select customer_history
```

### Result

Given a batch `2024-01-01` with Alice as `Active` and a batch `2024-01-02` with Alice as `Premium`:

| customer_id | status | dbt_valid_from | dbt_valid_to | dbt_change_type | changed_attributes |
|-------------|--------|----------------|--------------|-----------------|--------------------|
| 1 | Active | 2024-01-01 | 2024-01-02 | update | ["status"] |
| 1 | Premium | 2024-01-02 | NULL | insert | NULL |

If `2024-01-02` had been processed first, the next run would detect `2024-01-01` as late and rebuild both batches in the correct order.

## Documentation

| Guide | Contents |
|-------|----------|
| [How It Works](docs/HOW_IT_WORKS.md) | The problem, processing flow, out-of-order handling, full refresh |
| [Configuration](docs/CONFIGURATION.md) | All model parameters and project variables |
| [Output Tables](docs/OUTPUT_TABLES.md) | Snapshot columns, metadata and error log tables, example queries |
| [Advanced Usage](docs/ADVANCED_USAGE.md) | Composite keys, hard deletes, reprocessing, schema evolution, alerting, performance |
| [FAQ](docs/FAQ.md) | `updated_at` vs `sequence_by`, choosing a sequence column, and more |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common errors and how to fix them |

## Requirements

- **dbt**: 1.9.0 or higher, with `dbt-databricks`
- **Databricks**: Runtime 15.3+ or a Databricks SQL warehouse
- **Unity Catalog**: recommended
- A schema for the metadata tables (default `dbt_iterative_snapshot_metadata`)

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Code of Conduct

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) as it is our base for interaction.

## License

This project is licensed under the [MIT License](LICENSE).

## Provider Information

Please visit [https://group.mercedes-benz.com/provider/](https://group.mercedes-benz.com/provider/) for more information on the provider Mercedes-Benz Group AG.

**Notice**: Before you use this program in productive use, please take all necessary precautions such as testing and verifying the program with regard to your specific use. The source code has been tested solely for our own use cases, which might differ from yours.
