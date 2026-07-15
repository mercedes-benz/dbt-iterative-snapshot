{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
{#
  Override dbts default alias generation to support dev_table_prefix.
  This allows multiple developers/CI runs to use the same schema without conflicts.

  When dev_table_prefix is set, table names become: {prefix}_{schema}_{model_name}
  When dev_table_prefix is empty, table names remain: {model_name}
#}

{% macro generate_alias_name(custom_alias_name=none, node=none) -%}

    {%- if custom_alias_name -%}
        {{ custom_alias_name | trim }}

    {%- elif node.version -%}
        {{ return(node.name ~ "_v" ~ (node.version | replace(".", "_"))) }}

    {%- else -%}
        {%- set prefix = var('dev_table_prefix', '') -%}
        {%- set disable_prefix = var('disable_dev_table_prefix', false) -%}

        {%- if prefix and prefix != '' and not disable_prefix -%}
            {{ prefix }}_{{ target.schema }}_{{ node.name }}
        {%- else -%}
            {{ node.name }}
        {%- endif -%}

    {%- endif -%}

{%- endmacro %}
