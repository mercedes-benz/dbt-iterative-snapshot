{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}

{#
  Schema Evolution
  Adds columns that are new in the source query to the existing snapshot table before the staging
  table is built. Without this, check_cols='all' (and the timestamp strategy) reference the new column
  on the snapshot side and fail with UNRESOLVED_COLUMN.
  Columns are added with the data type of the source query. Columns removed from the source are never
  dropped (they are kept for SCD2 history) and only reported.
  Returns a dict of the detected changes: {'added': [...], 'removed': [...], 'not_in_check_cols': [...]}
#}
{% macro iterative_snapshot_handle_schema_evolution(target_relation, source_sql) %}

    {# Build an empty temporary view of the source so its column types can be described #}
    {%- set probe_relation = make_temp_relation(target_relation, '__schema_probe') -%}
    {%- call statement('iterative_snapshot_schema_probe') -%}
        {{ create_table_as(True, probe_relation, "select * from ( " ~ source_sql ~ " ) where 1=2") }}
    {%- endcall -%}

    {%- set source_columns = adapter.get_columns_in_relation(probe_relation) -%}
    {%- set target_columns = adapter.get_columns_in_relation(target_relation) -%}
    {%- set source_names = source_columns | map(attribute='name') | map('lower') | list -%}
    {%- set target_names = target_columns | map(attribute='name') | map('lower') | list -%}

    {%- set new_columns = [] -%}
    {%- for column in source_columns -%}
        {%- if column.name | lower not in target_names -%}
            {%- do new_columns.append(column) -%}
        {%- endif -%}
    {%- endfor -%}

    {# Columns present in the snapshot but gone from the source, excluding the snapshot's own meta columns #}
    {%- set snapshot_columns = config.get('snapshot_table_column_names') or get_snapshot_table_column_names() -%}
    {%- set meta_columns = [] -%}
    {%- for meta_column in ['dbt_scd_id', 'dbt_updated_at', 'dbt_valid_from', 'dbt_valid_to', 'dbt_change_type', 'inserted_at', 'changed_attributes'] -%}
        {%- do meta_columns.append(meta_column) -%}
        {%- do meta_columns.append(snapshot_columns.get(meta_column, meta_column) | lower) -%}
    {%- endfor -%}
    {%- set removed_columns = [] -%}
    {%- for column in target_columns -%}
        {%- if column.name | lower not in source_names and column.name | lower not in meta_columns -%}
            {%- do removed_columns.append(column.name) -%}
        {%- endif -%}
    {%- endfor -%}

    {# New columns that are not tracked by an explicit check_cols list will not create new SCD2 versions #}
    {%- set not_in_check_cols = [] -%}
    {%- if config.get('strategy') == 'check' and config.get('check_cols') is not string and config.get('check_cols') is iterable -%}
        {%- set check_cols_lower = config.get('check_cols') | map('lower') | list -%}
        {%- for column in new_columns -%}
            {%- if column.name | lower not in check_cols_lower -%}
                {%- do not_in_check_cols.append(column.name) -%}
            {%- endif -%}
        {%- endfor -%}
    {%- endif -%}

    {%- if new_columns | length > 0 -%}
        {%- do log("[Schema Evolution] : Adding new columns to " ~ target_relation ~ ": " ~ new_columns | map(attribute='name') | list, info=True) -%}
        {%- do create_columns(target_relation, new_columns) -%}
    {%- endif -%}
    {%- if not_in_check_cols | length > 0 -%}
        {%- do log("[Schema Evolution] WARNING: New columns are not in check_cols, changes to them will not create new SCD2 versions: " ~ not_in_check_cols, info=True) -%}
    {%- endif -%}
    {%- if removed_columns | length > 0 -%}
        {%- do log("[Schema Evolution] WARNING: Columns missing from source are kept in the snapshot for history: " ~ removed_columns, info=True) -%}
    {%- endif -%}

    {{ return({
        'added': new_columns | map(attribute='name') | list,
        'removed': removed_columns,
        'not_in_check_cols': not_in_check_cols
    }) }}

{% endmacro %}
