{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}

{%-  macro iterative_snapshot_check_for_inconsistencies(target_relation, unique_key, sequence_by)  -%} 
    {# 
        Check for inconsistencies in the SCD2 validity columns (dbt_valid_from,dbt_valid_to). 
        This query identifies records where the dbt_valid_to column does not align with the dbt_valid_from 
        column of the next row, indicating a potential inconsistency.
    #}
    
    {%-  set inconsistency_check_query  -%} 
        WITH ordered_data AS (
            SELECT
                {{ unique_key }} as unique_key,
                dbt_valid_from,
                dbt_valid_to,
                {{ sequence_by }},
                ROW_NUMBER() OVER (PARTITION BY {{ unique_key }} ORDER BY {{ sequence_by }}) AS row_num
            FROM {{ target_relation }}
        ),
        next_valid_from AS (
            SELECT
                a.unique_key,
                a.dbt_valid_from AS current_valid_from,
                a.dbt_valid_to AS current_valid_to,
                b.dbt_valid_from AS next_valid_from,
                a.row_num
            FROM ordered_data a
            LEFT JOIN ordered_data b
            ON a.unique_key = b.unique_key AND a.row_num = b.row_num - 1
            WHERE b.dbt_valid_from IS NOT NULL
        ),
        inconsistencies AS (
            SELECT
                unique_key
            FROM next_valid_from
            WHERE current_valid_to != next_valid_from
            OR (current_valid_to IS NOT NULL AND next_valid_from IS NULL)
        )

        SELECT COUNT(*) AS inconsistency_count FROM inconsistencies;
    {%-  endset  -%} 
    

    {%-  set inconsistency_count = run_query(inconsistency_check_query).columns[0].values()[0]  -%} 
    

    {{ return(inconsistency_count) }}

{%-  endmacro  -%} 


 



{#
  Create Metadata Table for tracking processed sequences
#}
{% macro create_metadata_table(table_name) %}
    {%- set table_parts = table_name.replace('`', '').split('.') -%}
    {%- set relation = api.Relation.create(
        database=table_parts[0],
        schema=table_parts[1],
        identifier=table_parts[2],
        type='table'
    ) -%}

    {%- set existing_relation = load_cached_relation(relation) -%}

    {# Row counts returned by the Databricks MERGE for each sequence #}
    {%- set merge_stats_columns = [
        'num_affected_rows BIGINT',
        'num_updated_rows BIGINT',
        'num_deleted_rows BIGINT',
        'num_inserted_rows BIGINT'
    ] -%}

    {%- if existing_relation -%}
        {# CREATE TABLE IF NOT EXISTS never alters an existing table, so backfill columns added in later versions #}
        {%- do dbt_iterative_snapshot.iterative_snapshot_add_missing_columns(existing_relation, merge_stats_columns) -%}
    {%- else -%}
        {%- set create_query -%}
            CREATE TABLE IF NOT EXISTS {{ table_name }} (
                invocation_id STRING,
                node_id STRING,
                model_name STRING,
                run_started_at TIMESTAMP,
                sequence STRING,
                inserted_at TIMESTAMP,
                processed_by STRING,
                {{ merge_stats_columns | join(',\n                ') }}
            )
            CLUSTER BY (model_name, sequence)
            TBLPROPERTIES (
                'delta.autoOptimize.optimizeWrite' = 'true',
                'delta.autoOptimize.autoCompact' = 'true'
            )
        {%- endset -%}
        {%- do run_query(create_query) -%}
        {%- do log("Created metadata table: " ~ table_name, info=True) -%}
    {%- endif -%}
{% endmacro %}

{#
  Add any column in column_definitions (e.g. 'num_inserted_rows BIGINT') that the relation does not already have
#}
{% macro iterative_snapshot_add_missing_columns(relation, column_definitions) %}
    {%- set existing_columns = adapter.get_columns_in_relation(relation) | map(attribute='name') | map('lower') | list -%}
    {%- set missing_definitions = [] -%}
    {%- for column_definition in column_definitions -%}
        {%- if column_definition.split(' ')[0] | lower not in existing_columns -%}
            {%- do missing_definitions.append(column_definition) -%}
        {%- endif -%}
    {%- endfor -%}

    {%- if missing_definitions | length > 0 -%}
        {%- do run_query("ALTER TABLE " ~ relation ~ " ADD COLUMNS (" ~ missing_definitions | join(', ') ~ ")") -%}
        {%- do log("Added missing columns to " ~ relation ~ ": " ~ missing_definitions, info=True) -%}
    {%- endif -%}
{% endmacro %}

{#
  Create Error Log Table for storing corrupted records
#}
{% macro create_error_log_table(table_name) %}
    {%- set create_query -%}
        CREATE TABLE IF NOT EXISTS {{ table_name }} (
            invocation_id STRING,
            node_id STRING,
            model_name STRING,
            run_started_at TIMESTAMP,
            sequence STRING,
            unique_key STRING,
            corrupted_record STRING,
            inserted_at TIMESTAMP,
            processed_by STRING
        )
        TBLPROPERTIES (
            'delta.autoOptimize.optimizeWrite' = 'true',
            'delta.autoOptimize.autoCompact' = 'true'
        )
    {%- endset -%}
    {%- do run_query(create_query) -%}
{% endmacro %}

{#
  Insert Metadata Record after processing a sequence.
  merge_stats: optional dict with num_affected_rows/num_updated_rows/num_deleted_rows/num_inserted_rows
  as returned by the Databricks MERGE, so consumers can tell "ran" apart from "ran and wrote rows".
#}
{% macro insert_metadata_record(table_name, invocation_id, node_id, run_started_at, model_name, sequence, merge_stats=none) %}
    {%- set merge_stats = merge_stats or {} -%}
    {%- set insert_query -%}
        INSERT INTO {{ table_name }} (
            invocation_id,
            node_id,
            model_name,
            run_started_at,
            sequence,
            inserted_at,
            processed_by,
            num_affected_rows,
            num_updated_rows,
            num_deleted_rows,
            num_inserted_rows
        )
        VALUES (
            '{{ invocation_id }}',
            '{{ node_id }}',
            '{{ model_name }}',
            CAST('{{ run_started_at }}' AS TIMESTAMP),
            '{{ sequence }}',
            current_timestamp(),
            current_user(),
            {%- for stat in ['num_affected_rows', 'num_updated_rows', 'num_deleted_rows', 'num_inserted_rows'] %}
            {{ merge_stats.get(stat) if merge_stats.get(stat) is not none else 'NULL' }}{{ ',' if not loop.last }}
            {%- endfor %}
        )
    {%- endset -%}
    {%- do run_query(insert_query) -%}
    {%- do log("Logged sequence '" ~ sequence ~ "' to metadata table", info=True) -%}
{% endmacro %}
