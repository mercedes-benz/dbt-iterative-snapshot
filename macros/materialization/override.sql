{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
{% macro snapshot_check_all_get_existing_columns(node, target_exists, check_cols_config) -%}

{% if node.config.materialized == 'iterative_snapshot' %}
    {# overriding to prevent checking if table exists and returning no columns for check strategy : https://github.com/dbt-labs/dbt-adapters/blob/main/dbt/include/global_project/macros/materializations/snapshots/strategies.sql #}

    {% if check_cols_config == 'all' %}
        {%- set query_columns = get_columns_in_query(node['compiled_code']) -%}

    {% elif check_cols_config is iterable and (check_cols_config | length) > 0 %}
        {%- set select_check_cols_from_target -%}
            select {{ check_cols_config | join(', ') }} from (
                {{ node['compiled_code'] }}
            ) subq
        {%- endset -%}

        {% set query_columns = get_columns_in_query(select_check_cols_from_target) %}
    {% else %}
        {% do exceptions.raise_compiler_error("Invalid value for 'check_cols': " ~ check_cols_config) %}
    {% endif %}


    {%- set intersection = [] -%}
    {%- for col in query_columns -%}
        {%- do intersection.append(adapter.quote(col)) -%}
    {%- endfor -%}

    {{ return((False, intersection)) }}


{% else %}

    {#-- Determine query_columns first for both target_exists cases --#}
    {% if check_cols_config == 'all' %}
        {%- set query_columns = get_columns_in_query(node['compiled_code']) -%}

    {% elif check_cols_config is iterable and (check_cols_config | length) > 0 %}
        {%- set select_check_cols_from_target -%}
            select {{ check_cols_config | join(', ') }} from (
                {{ node['compiled_code'] }}
            ) subq
        {%- endset -%}
        {% set query_columns = get_columns_in_query(select_check_cols_from_target) %}

    {% else %}
        {% do exceptions.raise_compiler_error("Invalid value for 'check_cols': " ~ check_cols_config) %}
    {% endif %}

    {%- if not target_exists -%}
        {#-- no table yet -> return whatever the query does --#}
        {{ return((false, query_columns)) }}
    {%- endif -%}

    {#-- handle any schema changes --#}
    {%- set target_relation = adapter.get_relation(database=node.database, schema=node.schema, identifier=node.alias) -%}
    {%- set existing_cols = adapter.get_columns_in_relation(target_relation) | map(attribute = 'name') | list -%}
    {%- set ns = namespace() -%} {#-- handle for-loop scoping with a namespace --#}
    {%- set ns.column_added = false -%}

    {%- set intersection = [] -%}
    {%- for col in query_columns -%}
        {%- if col in existing_cols -%}
            {%- do intersection.append(adapter.quote(col)) -%}
        {%- else -%}
            {% set ns.column_added = true %}
        {%- endif -%}
    {%- endfor -%}
    {{ return((ns.column_added, intersection)) }}

{% endif %}

{%- endmacro %}


{% macro build_iterative_snapshot_table(strategy, sql) %}

        {% set columns = config.get('snapshot_table_column_names') or get_snapshot_table_column_names() %}

        select *,
            {{ strategy.scd_id }} as {{ columns.get("dbt_scd_id", "dbt_scd_id") }},
            {{ strategy.updated_at }} as {{ columns.get("dbt_updated_at", "dbt_updated_at")  }},
            {{ strategy.updated_at }} as {{ columns.get("dbt_valid_from", "dbt_valid_from") }},
            {{ get_dbt_valid_to_current(strategy, columns) }},
            cast(null as timestamp) as {{ columns.get("inserted_at", "inserted_at") }},
            '' as {{ columns.get("dbt_change_type", "dbt_change_type") }},
            parse_json(null) as changed_attributes
        from (
            {{ sql }}
        ) sbq

{% endmacro %}


{% macro get_iterative_snapshot_merge_sql(target, source, insert_cols) -%}

    {%- set insert_cols_csv = insert_cols | join(', ') -%}

    {%- set columns = config.get("snapshot_table_column_names") or get_snapshot_table_column_names() -%}

    merge into {{ target.render() }} as DBT_INTERNAL_DEST
    using {{ source }} as DBT_INTERNAL_SOURCE
    on DBT_INTERNAL_SOURCE.{{ columns.get("dbt_scd_id", "dbt_scd_id") }} = DBT_INTERNAL_DEST.{{ columns.get("dbt_scd_id", "dbt_scd_id") }}

    when matched
        {% if config.get("dbt_valid_to_current") %}
        and (DBT_INTERNAL_DEST.{{ columns.get("dbt_valid_to", "dbt_valid_to") }} = {{ config.get('dbt_valid_to_current') }} or
            DBT_INTERNAL_DEST.{{ columns.get("dbt_valid_to", "dbt_valid_to") }} is null)
        {% else %}
        and DBT_INTERNAL_DEST.{{ columns.get("dbt_valid_to", "dbt_valid_to") }} is null
        {% endif %}
        and DBT_INTERNAL_SOURCE.dbt_change_type in ('update', 'delete')
        then update
            set {{ columns.get("dbt_valid_to", "dbt_valid_to") }} = DBT_INTERNAL_SOURCE.{{ columns.get("dbt_valid_to", "dbt_valid_to") }}
            ,{{ columns.get("dbt_change_type", "dbt_change_type") }} = DBT_INTERNAL_SOURCE.dbt_change_type
            ,changed_attributes = DBT_INTERNAL_SOURCE.changed_attributes


    when not matched
    and DBT_INTERNAL_SOURCE.dbt_change_type = 'insert'
        then insert ({{ insert_cols_csv }}, {{ columns.get("inserted_at", "inserted_at") }})
        values ({{ insert_cols_csv }}, current_timestamp())


{% endmacro %}


{% macro iterative_snapshot_get_changed_attributes(check_cols_config, snapshot_table_alias, source_table_alias) -%}

    parse_json(
        to_json(
            array_compact(
                array(
                    {%- for col in check_cols_config %}
                        if(
                            not ({{ snapshot_table_alias }}.`{{ col }}` <=> {{ source_table_alias }}.`{{ col }}`),
                            '{{ col }}',
                            null
                        ){% if not loop.last %},{% endif %}
                    {%- endfor %}
                )
            )
        )
    )

{%- endmacro %}



{#- Flat null-safe replacement for dbt's check-strategy row_changed: one expression per column instead of
    an OR of three, which keeps Spark's ConstantPropagation recursion shallow and avoids StackOverflowError
    on wide models. Semantically equivalent for the check strategy. -#}
{% macro iterative_snapshot_row_changed(check_cols_config, snapshot_table_alias, source_table_alias) -%}
    (
        {%- for col in check_cols_config %}
        not ({{ snapshot_table_alias }}.`{{ col }}` <=> {{ source_table_alias }}.`{{ col }}`)
        {%- if not loop.last %} or {% endif %}
        {%- endfor %}
    )
{%- endmacro %}



{% macro iterative_snapshot_staging_table(strategy, source_sql, target_relation, check_cols_config) -%}


    {% set columns = config.get('snapshot_table_column_names') or get_snapshot_table_column_names() %}

    {#- The timestamp strategy compares updated_at, so only the check strategy uses the flat column comparison -#}
    {%- if config.get('strategy') == 'check' and check_cols_config -%}
        {%- set row_changed = dbt_iterative_snapshot.iterative_snapshot_row_changed(check_cols_config, "snapshotted_data", "source_data") -%}
    {%- else -%}
        {%- set row_changed = strategy.row_changed -%}
    {%- endif -%}

    with snapshot_query as (

        {{ source_sql }}

    ),

    snapshotted_data as (

        select *, {{ unique_key_fields(strategy.unique_key) }}
        from {{ target_relation }}
        where
            {% if config.get('dbt_valid_to_current') %}
               {# Check for either dbt_valid_to_current OR null, in order to correctly update records with nulls #}
               ( {{ columns.get("dbt_valid_to","dbt_valid_to") }} = {{ config.get('dbt_valid_to_current') }} or {{ columns.get("dbt_valid_to","dbt_valid_to") }} is null)
            {% else %}
                {{ columns.get("dbt_valid_to","dbt_valid_to") }} is null
            {% endif %}

    ),

    insertions_source_data as (

        select *, {{ unique_key_fields(strategy.unique_key) }},
            {{ strategy.updated_at }} as {{ columns.get("dbt_updated_at","dbt_updated_at") }},
            {{ strategy.updated_at }} as {{ columns.get("dbt_valid_from","dbt_valid_from") }},
            {{ get_dbt_valid_to_current(strategy, columns) }},
            {{ strategy.scd_id }} as {{ columns.get("dbt_scd_id","dbt_scd_id") }}

        from snapshot_query
    ),

    updates_source_data as (

        select *, {{ unique_key_fields(strategy.unique_key) }},
            {{ strategy.updated_at }} as {{ columns.get("dbt_updated_at","dbt_updated_at") }},
            {{ strategy.updated_at }} as {{ columns.get("dbt_valid_from","dbt_valid_from") }},
            {{ strategy.updated_at }} as {{ columns.get("dbt_valid_to","dbt_valid_to") }}

        from snapshot_query
    ),

    {%- if strategy.invalidate_hard_deletes %}

    deletes_source_data as (

        select *, {{ unique_key_fields(strategy.unique_key) }}
        from snapshot_query
    ),
    {% endif %}

    insertions as (

        select
            parse_json(null) as changed_attributes,
            'insert' as dbt_change_type,
            source_data.*

        from insertions_source_data as source_data
        left outer join snapshotted_data
            on {{ unique_key_join_on(strategy.unique_key, "snapshotted_data", "source_data") }}
            where {{ unique_key_is_null(strategy.unique_key, "snapshotted_data") }}
            or ({{ unique_key_is_not_null(strategy.unique_key, "snapshotted_data") }} and ({{ row_changed }})

        )
    ),

    updates as (

        select
            {{ dbt_iterative_snapshot.iterative_snapshot_get_changed_attributes(check_cols_config, "snapshotted_data", "source_data") }} as changed_attributes,
            'update' as dbt_change_type,
            source_data.*,
            snapshotted_data.{{ columns.get("dbt_scd_id","dbt_scd_id") }}

        from updates_source_data as source_data
        join snapshotted_data
            on {{ unique_key_join_on(strategy.unique_key, "snapshotted_data", "source_data") }}
        where (
            {{ row_changed }}
        )
    )

    {%- if strategy.invalidate_hard_deletes -%}
    ,

    deletes as (

        select
            parse_json(null) as changed_attributes,
            'delete' as dbt_change_type,
            source_data.*,
            {{ snapshot_get_time() }} as {{ columns.get("dbt_valid_from","dbt_valid_from") }},
            {{ snapshot_get_time() }} as {{ columns.get("dbt_updated_at","dbt_updated_at") }},
            {{ snapshot_get_time() }} as {{ columns.get("dbt_valid_to","dbt_valid_to") }},
            snapshotted_data.{{ columns.get("dbt_scd_id","dbt_scd_id") }}

        from snapshotted_data
        left join deletes_source_data as source_data
            on {{ unique_key_join_on(strategy.unique_key, "snapshotted_data", "source_data") }}
            where {{ unique_key_is_null(strategy.unique_key, "source_data") }}
    )
    {%- endif %}

    select * from insertions
    union all
    select * from updates
    {%- if strategy.invalidate_hard_deletes %}
    union all
    select * from deletes
    {%- endif %}


{% endmacro %}



{% macro build_iterative_snapshot_staging_table(strategy, sql, target_relation, check_cols_config) %}
    {#- materialize_staging=true builds a physical table instead of a temporary view, so Spark optimizes the
        staging expression tree once at CTAS instead of inlining it into the MERGE plan. Use it when wide
        check_cols/unique_key models still hit StackOverflowError. -#}
    {% set as_table = config.get('materialize_staging', var('materialize_staging', false)) %}

    {% set temp_relation = make_temp_relation(target_relation) %}
    {%- if as_table -%}
        {#- Physical tables need full qualification and a per-invocation suffix: unlike session-scoped
            temporary views, they would collide across concurrent runs of the same model -#}
        {% set temp_relation = temp_relation.incorporate(path={
            "database": target_relation.database,
            "schema": target_relation.schema,
            "identifier": temp_relation.identifier ~ '_' ~ invocation_id.replace('-', '')[:8]
        }) %}
    {%- endif -%}

    {% set select = dbt_iterative_snapshot.iterative_snapshot_staging_table(strategy, sql, target_relation, check_cols_config) %}

    {% call statement('build_iterative_snapshot_staging_table') %}
        {{ create_table_as(not as_table, temp_relation, select) }}
    {% endcall %}

    {% do return(temp_relation) %}
{% endmacro %}
