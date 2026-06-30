# dbt-iterative-snapshot

> **SCD2 snapshots that process data batches in sequence — even when they arrive out of order**

[![dbt Version](https://img.shields.io/badge/dbt-1.6%2B-orange.svg)](https://getdbt.com)
[![Databricks](https://img.shields.io/badge/Databricks-Unity%20Catalog-orange.svg)](https://databricks.com)
[![License](https://img.shields.io/badge/License-MIT-brightgreen.svg)](LICENSE)

> **Note**: This is an open source project by Mercedes-Benz Group AG. Source code has been tested solely for our own use cases, which might differ from yours.

---

## The Problem

You receive daily data batches — whether from file exports, database snapshots, CDC streams, or API syncs. Monday's batch arrives, then Wednesday's — but Tuesday's batch is delayed:

```mermaid
timeline
    title Data Batch Arrival vs Processing Order
    section Arrival Order
        Monday : batch_2024-01-01 ✓
        Wednesday : batch_2024-01-03 ✓
        Thursday : batch_2024-01-02 ✓ (late!)
    section Correct Processing Order
        First : batch_2024-01-01
        Second : batch_2024-01-02
        Third : batch_2024-01-03
```

**With standard dbt snapshots**: Tuesday's late batch corrupts your SCD2 history. Records show impossible timelines — changes appearing *before* they happened.

**With iterative-snapshot**: The package detects the out-of-order batch, backs up affected records, reprocesses from Tuesday onwards, and restores correct SCD2 history automatically.

---

## 30-Second Example

```sql
-- models/employee_history.sql
{{ config(
    materialized='iterative_snapshot',
    unique_key='employee_id',
    updated_at='modified_date',
    sequence_by='batch_date',        -- processes batches in this order
    strategy='check',
    check_cols=['department', 'salary', 'status']
) }}

SELECT * FROM {{ source('hr', 'employee_data') }}
```

**Input**: 3 daily batches with employee changes  
**Output**: Complete SCD2 history table with `dbt_valid_from`, `dbt_valid_to`, and `dbt_change_type`

The `sequence_by` column is the key — it tells the package *which order* to process batches, regardless of when they physically arrived.

---

## When to Use This Package

| Scenario | Standard Snapshot | Iterative Snapshot |
|----------|:-----------------:|:-----------------:|
| Source is a live database table (single snapshot per run) | ✅ | — |
| Source is sequential data batches (files, CDC, API syncs) | — | ✅ |
| Batches can arrive out of order | ❌ | ✅ |
| Need to reprocess historical batches | ❌ | ✅ |
| Want audit trail of processed batches | — | ✅ |

---

## Why This Package Exists

> **Standard dbt snapshots assume your data arrives in order. Real-world data doesn't.**

### The 3 Guarantees

| Guarantee | What It Means |
|-----------|---------------|
| **Safe Backfill** | Load a month-old file without losing data — records automatically slot into correct SCD2 positions |
| **Self-Healing History** | Out-of-order batches are detected and reprocessed automatically — no corrupted timelines |
| **Audit-Ready** | Every batch is logged with metadata — answer "what was the state on date X?" with certainty |

### Community Demand

This package addresses long-standing gaps in dbt's snapshot functionality that remain unresolved after years of community requests:

| dbt-core Issue | Problem | How We Solve It |
|----------------|---------|-----------------|
| [#7138](https://github.com/dbt-labs/dbt-core/issues/7138) | Non-chronological insertions corrupt SCD2 history | Detects out-of-order sequences, backs up affected records, reprocesses in correct order |
| [#9892](https://github.com/dbt-labs/dbt-core/issues/9892) | No way to backfill or rebase historical snapshots | **Backfill**: sequence-based processing loads historical batches in correct order. **Rebase**: `--full-refresh` rebuilds with new strategy while preserving history outside retention window |
| [#3878](https://github.com/dbt-labs/dbt-core/issues/3878) | Snapshots can't handle append-only source tables | Processes one sequence at a time, preventing merge conflicts from multiple rows per key |

**Standard dbt snapshots assume**:
- Source data is a live table (not sequential batches)
- Data arrives in chronological order
- One row per unique key in each run

**This package handles**:
- Sequential batch processing via `sequence_by`
- Automatic out-of-order detection and correction
- Multiple rows per key across batches (daily full exports, CDC events)
- Metadata tracking of which sequences were processed

---

## Installation

Add to your `packages.yml`:

```yaml
packages:
  - package: mercedes-benz/dbt_iterative_snapshot
    version: [">=1.0.0", "<2.0.0"]
```

Then run:

```bash
dbt deps
```

---

## Quick Start

### Step 1: Define Your Source

Your source data needs a **sequence column** - a column that identifies which batch each record came from (e.g., `batch_date`, `batch_id`, `load_timestamp`, `kafka_offset`).

```yaml
# models/sources.yml
sources:
  - name: raw
    tables:
      - name: customer_updates
        description: "Daily customer data batches"
```

### Step 2: Create Your Snapshot Model

```sql
-- models/snapshots/customer_history.sql
{{ config(
    materialized='iterative_snapshot',
    unique_key='customer_id',
    updated_at='modified_date',
    sequence_by='batch_date',
    strategy='check',
    check_cols=['name', 'email', 'status']
) }}

SELECT
    customer_id,
    name,
    email,
    status,
    modified_date,
    batch_date
FROM {{ source('raw', 'customer_updates') }}
```

### Step 3: Run It

```bash
dbt run --select customer_history
```

---

## How It Works

### Processing Flow

```mermaid
flowchart TB
    subgraph Input["Source Data"]
        B1[batch_01]
        B2[batch_02]
        B3[batch_03]
    end

    subgraph Process["iterative_snapshot Materialization"]
        M1[1. Check metadata for unprocessed sequences]
        M2[2. Detect out-of-order batches]
        M3{Out of order?}
        M4[Backup & delete affected records]
        M5[3. Process each sequence via MERGE]
        M6[4. Log to metadata table]
        M7[5. Validate SCD2 consistency]
    end

    subgraph Output["Output Tables"]
        O1[(Snapshot Table\nSCD2 History)]
        O2[(Metadata Table\nAudit Trail)]
        O3[(Error Log\nData Quality)]
    end

    B1 & B2 & B3 --> M1
    M1 --> M2
    M2 --> M3
    M3 -->|Yes| M4
    M4 --> M5
    M3 -->|No| M5
    M5 --> M6
    M6 --> M7
    M7 --> O1 & O2
    M5 -.->|Duplicates found| O3

    style M3 fill:#ff9800
    style O1 fill:#4caf50
    style O2 fill:#2196f3
    style O3 fill:#f44336
```

### Example: Processing Daily Batches

**Day 1**: Batch `2024-01-01` arrives with initial customer data:

| customer_id | name | status | batch_date |
|-------------|------|--------|------------|
| 1 | Alice | Active | 2024-01-01 |
| 2 | Bob | Active | 2024-01-01 |

**Day 2**: Batch `2024-01-02` arrives with updates:

| customer_id | name | status | batch_date |
|-------------|------|--------|------------|
| 1 | Alice | Premium | 2024-01-02 |
| 3 | Carol | Active | 2024-01-02 |

**Result**: SCD2 snapshot table with full history:

| customer_id | name | status | dbt_valid_from | dbt_valid_to | dbt_change_type |
|-------------|------|--------|----------------|--------------|-----------------|
| 1 | Alice | Active | 2024-01-01 | 2024-01-02 | insert |
| 1 | Alice | Premium | 2024-01-02 | NULL | update |
| 2 | Bob | Active | 2024-01-01 | NULL | insert |
| 3 | Carol | Active | 2024-01-02 | NULL | insert |

### Out-of-Order Batch Handling

```mermaid
sequenceDiagram
    participant Raw as Raw Data
    participant IS as Iterative Snapshot
    participant Meta as Metadata Table
    participant Snap as Snapshot Table

    Note over Raw,Snap: Normal flow: batch_02 arrives first
    Raw->>IS: batch_02 (2024-01-02)
    IS->>Meta: Check: no prior sequences
    IS->>Snap: MERGE batch_02
    IS->>Meta: Log: batch_02 processed

    Note over Raw,Snap: Out-of-order: batch_01 arrives late!
    Raw->>IS: batch_01 (2024-01-01)
    IS->>Meta: Check: batch_02 already processed
    IS-->>IS: DETECT: batch_01 < batch_02 ⚠️
    
    rect rgb(255, 235, 205)
        Note over IS,Snap: Automatic Recovery
        IS->>Snap: Backup records from batch_02
        IS->>Snap: DELETE batch_02 records
        IS->>Meta: Clear batch_02 from metadata
        IS->>Snap: MERGE batch_01 (correct order)
        IS->>Snap: MERGE batch_02 (reprocess)
        IS->>Meta: Log both sequences
    end
    
    Note over Snap: ✓ SCD2 history is correct!
```

---

## Configuration Reference

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `materialized` | string | Must be `'iterative_snapshot'` |
| `unique_key` | string or list | Primary key column(s) for SCD2 |
| `updated_at` | string | Timestamp column from source system |
| `sequence_by` | string | Column identifying batch sequence (date, ID, offset) |
| `strategy` | string | `'check'` or `'timestamp'` |
| `check_cols` | list or string | Columns to monitor for changes (use `'all'` for all columns) |

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `invalidate_hard_deletes` | `false` | Track when records are deleted from source |
| `enable_data_quality_checks` | `true` | Detect duplicate keys within same sequence |

### Project-Level Configuration

Configure defaults in your `dbt_project.yml`:

```yaml
vars:
  # Feature toggles
  enable_data_quality_checks: true
  enable_error_logging: true
  enable_consistency_checks: true
  enable_temp_views: true
  
  # Metadata table location (schema must exist)
  metadata_schema: "dbt_iterative_snapshot_metadata"
```

---

## Output Tables

```mermaid
erDiagram
    SNAPSHOT_TABLE ||--o{ METADATA_TABLE : "tracked by"
    SNAPSHOT_TABLE ||--o{ ERROR_LOG : "quality issues"
    
    SNAPSHOT_TABLE {
        string dbt_scd_id PK "Unique hash for record version"
        timestamp dbt_valid_from "When version became active"
        timestamp dbt_valid_to "When superseded (NULL=current)"
        timestamp dbt_updated_at "Source system timestamp"
        string dbt_change_type "insert/update/delete"
        json changed_attributes "Which columns changed"
        timestamp inserted_at "When row was inserted"
    }
    
    METADATA_TABLE {
        string invocation_id "dbt run ID"
        string model_name "Snapshot model name"
        string sequence "Processed sequence value"
        timestamp run_started_at "When processing started"
        timestamp inserted_at "When logged"
        string processed_by "User who ran it"
    }
    
    ERROR_LOG {
        string model_name "Snapshot model name"
        string sequence "Sequence with issues"
        string unique_key "Duplicate key value"
        json corrupted_record "Full record data"
        timestamp inserted_at "When logged"
    }
```

### Querying the Tables

```sql
-- Current records (where dbt_valid_to IS NULL)
SELECT * FROM my_snapshot WHERE dbt_valid_to IS NULL;

-- History for a specific customer
SELECT * FROM my_snapshot 
WHERE customer_id = 123 
ORDER BY dbt_valid_from;

-- Check which batches have been processed
SELECT * FROM my_catalog.metadata_schema.iterative_snapshot_metadata
WHERE model_name = 'my_snapshot'
ORDER BY sequence;

-- Find data quality issues
SELECT * FROM my_catalog.metadata_schema.iterative_snapshot_error_log
WHERE model_name = 'my_snapshot';
```

---

## Advanced Usage

### Composite Unique Key

```sql
{{ config(
    materialized='iterative_snapshot',
    unique_key=['region', 'customer_id'],
    updated_at='modified_date',
    sequence_by='batch_date',
    strategy='check',
    check_cols='all'
) }}
```

### Track All Column Changes

```sql
{{ config(
    ...
    check_cols='all'  -- Monitors all columns for changes
) }}
```

### Hard Delete Tracking

```sql
{{ config(
    ...
    invalidate_hard_deletes=true  -- Mark missing records as deleted
) }}
```

### Full Refresh with History Preservation

```bash
dbt run --select customer_history --full-refresh
```

This will:
1. Back up historical records outside the raw data retention window
2. Rebuild the snapshot from current raw data (with current strategy/config)
3. Restore the historical records (preserving full SCD2 history)

### Rebasing After Strategy Changes

If you change your snapshot configuration (e.g., adding columns to `check_cols`), use `--full-refresh` to reprocess all data with the new strategy:

```sql
-- Before: only tracked status changes
{{ config(
    ...
    check_cols=['status']
) }}

-- After: now also track email changes
{{ config(
    ...
    check_cols=['status', 'email']
) }}
```

```bash
# Reprocess all sequences with new check_cols
dbt run --select customer_history --full-refresh
```

**Note**: Historical records outside your raw data retention window are preserved but not reprocessed (the original data is no longer available). Only sequences still present in your raw source are rebuilt with the new strategy.

---

## Architecture Deep Dive

### Component Overview

```mermaid
graph LR
    subgraph Macros["Core Macros"]
        IS[iterative_snapshot.sql<br/>Main materialization]
        OV[override.sql<br/>Staging & merge logic]
        HE[helpers.sql<br/>Consistency checks]
        DB[databricks_utils.sql<br/>Platform-specific SQL]
    end

    subgraph Tables["Runtime Tables"]
        SN[(Snapshot)]
        MT[(Metadata)]
        EL[(Error Log)]
        BK[(Backup - temp)]
    end

    IS --> OV
    IS --> HE
    IS --> DB
    
    OV --> SN
    IS --> MT
    IS --> EL
    IS -.-> BK

    style IS fill:#e1f5fe
    style SN fill:#c8e6c9
    style MT fill:#fff3e0
    style EL fill:#ffcdd2
```

### Processing States

```mermaid
stateDiagram-v2
    [*] --> CheckMetadata: dbt run
    CheckMetadata --> NoWork: All sequences processed
    CheckMetadata --> DetectOrder: Unprocessed sequences found
    
    DetectOrder --> NormalProcess: In order
    DetectOrder --> OutOfOrder: Out of order detected
    
    OutOfOrder --> BackupRecords: Backup affected data
    BackupRecords --> DeleteSequences: Clear for reprocessing
    DeleteSequences --> NormalProcess: Ready to process
    
    NormalProcess --> ProcessSequence: For each sequence
    ProcessSequence --> BuildStaging: Create staging table
    BuildStaging --> MergeSnapshot: MERGE into snapshot
    MergeSnapshot --> LogMetadata: Record processed
    LogMetadata --> ProcessSequence: Next sequence
    LogMetadata --> ValidateConsistency: All done
    
    ValidateConsistency --> FixGaps: Inconsistencies found
    FixGaps --> [*]: Complete
    ValidateConsistency --> [*]: Complete
    NoWork --> [*]: Nothing to do
```

---

## Requirements

- **dbt**: 1.6.0 or higher
- **Databricks**: Runtime 10.4+
- **Unity Catalog**: Recommended for 3-part naming

---

## Performance Tips

### 1. Use Temporary Views (Default: Enabled)
Reduces repeated query compilation when processing multiple sequences.

### 2. Large Batches
For very large batches, consider processing in smaller chunks by filtering your source query.

### 3. Disable Checks for Speed
For trusted data sources:
```sql
{{ config(
    ...
    enable_data_quality_checks=false,
    enable_consistency_checks=false
) }}
```

---

## FAQ

### Q: What's the difference between `updated_at` and `sequence_by`?

- **`updated_at`**: Timestamp from your source system (when the record was modified)
- **`sequence_by`**: Which batch the record came from (controls processing order)

Example: A record modified on Jan 15 (`updated_at`) might arrive in the Jan 20 batch (`sequence_by`).

### Q: What can I use as a `sequence_by` value?

Any monotonically increasing value that identifies your batches:
- Dates (`batch_date`, `snapshot_date`)
- Batch/load IDs (`batch_id`, `load_id`)
- Timestamps (`load_timestamp`, `extracted_at`)
- Stream offsets (`kafka_offset`, `cdc_sequence`)
- File identifiers (`file_date`, `file_id`)

### Q: How do I reprocess a specific batch?

Delete its entry from the metadata table, then re-run:
```sql
DELETE FROM your_catalog.metadata_schema.iterative_snapshot_metadata
WHERE model_name = 'my_snapshot' AND sequence = '2024-01-15';
```
```bash
dbt run --select my_snapshot
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| "No object to process" | All sequences already processed | Check for new data or use `--full-refresh` |
| Duplicate key errors in log | Multiple records with same key in one batch | Clean source data or adjust unique_key |
| Out-of-order reprocessing slow | Rebuilding many sequences | Ensure batches arrive in order when possible |
| Metadata table not found | Schema doesn't exist | Create schema or update `metadata_schema` var |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Code of Conduct

Please read our [Code of Conduct](https://github.com/mercedes-benz/.github/blob/main/CODE_OF_CONDUCT.md) as it is our base for interaction.

## License

This project is licensed under the [MIT License](LICENSE).

## Provider Information

Please visit [https://www.mercedes-benz.com/en/providerdisclosure/](https://www.mercedes-benz.com/en/providerdisclosure/) for more information on the provider Mercedes-Benz Group AG.

**Notice:** Before you use this program in productive use, please take all necessary precautions such as testing and verifying the program with regard to your specific use. The source code has been tested solely for our own use cases, which might differ from yours.
