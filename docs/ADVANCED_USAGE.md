# Advanced Usage

## Composite Unique Key

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

## Hard Delete Tracking

Records that are missing from a batch are closed with `dbt_change_type = 'delete'`:

```sql
{{ config(
    ...
    invalidate_hard_deletes=true
) }}
```

## Full Refresh with History Preservation

```bash
dbt run --select customer_history --full-refresh
```

This will:
1. Back up historical records outside the raw data retention window
2. Rebuild the snapshot from current raw data with your current config
3. Restore the historical records, preserving full SCD2 history

See [How It Works](HOW_IT_WORKS.md#full-refresh) for details.

## Rebasing After Strategy Changes

Changed your `check_cols`? Use `--full-refresh` to reprocess all data with the new configuration:

```bash
dbt run --select customer_history --full-refresh
```

Historical records outside your raw data retention window are preserved but not reprocessed, because their original data is no longer available.

## Reprocessing a Specific Batch

Delete its metadata entry and re-run. The batch is picked up as unprocessed, and it and all later batches are reprocessed in order:

```sql
DELETE FROM my_catalog.dbt_iterative_snapshot_metadata.iterative_snapshot_metadata
WHERE model_name = 'my_snapshot' AND sequence = '2024-01-15';
```

```bash
dbt run --select my_snapshot
```

## Schema Evolution

When the source query gains a column, it is added to the snapshot table (with the source data type) before the next sequence is merged. Existing rows get `NULL`.

- Columns that disappear from the source are never dropped; they are kept for history and a warning is logged.
- With an explicit `check_cols` list, new columns that are not in the list are reported, because changes to them will not create new versions.

Disable with `enable_schema_evolution=false`.

## Alerting via Event Hook

The materialization calls `iterative_snapshot_on_event(event_type, model_name, relation, details)` for these events:

| `event_type` | `details` keys |
|--------------|----------------|
| `duplicate_records` | `sequence`, `duplicate_count`, `error_log_table` |
| `out_of_order` | `incoming_sequences`, `max_processed_sequence` |
| `schema_change` | `added`, `removed`, `not_in_check_cols` |

The default implementation only logs. To send your own notifications, override it in your project:

```sql
-- macros/iterative_snapshot_events.sql
{% macro default__iterative_snapshot_on_event(event_type, model_name, relation, details) %}
    {% do log("ALERT " ~ event_type ~ " on " ~ relation ~ ": " ~ details, info=True) %}
    {# e.g. insert into an alerts table or call your notification macro #}
{% endmacro %}
```

```yaml
# dbt_project.yml
dispatch:
  - macro_namespace: dbt_iterative_snapshot
    search_order: ['my_project', 'dbt_iterative_snapshot']
```

## Performance Tips

1. **Temporary views** (enabled by default) read the source query once instead of once per sequence.
2. **Liquid clustering**: the metadata table is clustered by `(model_name, sequence)`. For large snapshot tables, add `liquid_clustered_by=[...]` to the model config (see [Configuration](CONFIGURATION.md#liquid-clustering)).
3. **Trusted data**: disable checks you don't need:
   ```sql
   {{ config(
       ...
       enable_data_quality_checks=false,
       enable_consistency_checks=false
   ) }}
   ```
4. **Very wide models** (hundreds of `check_cols`) can hit Spark `StackOverflowError` while planning the MERGE. Change detection for the `check` strategy already uses a flat null-safe comparison. If the error persists, set `materialize_staging=true` (see [Troubleshooting](TROUBLESHOOTING.md#stackoverflowerror-during-merge-on-wide-models)).
