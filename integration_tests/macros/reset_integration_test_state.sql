{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
{#
  Drop the snapshot, metadata and error log tables left by previous runs, so every
  integration test run processes all sequences from scratch like a first-time user.

  Usage: dbt run-operation reset_integration_test_state
#}

{% macro reset_integration_test_state() %}

    {%- set dev_prefix = var('dev_table_prefix', '') -%}
    {%- set disable_prefix = var('disable_dev_table_prefix', false) -%}
    {%- set metadata_schema = var('metadata_schema', 'dbt_iterative_snapshot_metadata') -%}
    {%- set table_prefix = dev_prefix ~ '_' ~ target.schema ~ '_' if dev_prefix and not disable_prefix else '' -%}

    {%- set tables = [] -%}
    {%- for base_name in ['iterative_snapshot_metadata', 'iterative_snapshot_error_log'] -%}
        {%- do tables.append('`' ~ target.catalog ~ '`.`' ~ metadata_schema ~ '`.`' ~ table_prefix ~ base_name ~ '`') -%}
    {%- endfor -%}
    {%- for node in graph.nodes.values()
        if node.resource_type == 'model'
        and node.package_name == project_name
        and node.config.materialized == 'iterative_snapshot' -%}
        {%- do tables.append('`' ~ node.database ~ '`.`' ~ node.schema ~ '`.`' ~ node.alias ~ '`') -%}
    {%- endfor -%}

    {%- for table in tables -%}
        {%- do log('Dropping ' ~ table, info=True) -%}
        {%- do run_query('DROP TABLE IF EXISTS ' ~ table) -%}
    {%- endfor -%}

{% endmacro %}
