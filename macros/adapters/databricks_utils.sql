{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
{#
  Databricks Utility Macros
  Provides Databricks-specific SQL generation for the iterative snapshot materialization
  Using Unity Catalog and Delta Lake features
#}

{#
  Create JSON from Struct for Databricks
  Used for logging corrupted records
#}
{% macro create_json_from_struct() %}
    to_json(struct(*))
{% endmacro %}

{#
  Enforce Validity Columns SQL for Databricks
  Fixes SCD2 validity gaps when a deleted record becomes active again
#}
{% macro get_enforce_validity_columns_sql(target_relation, unique_key_concat, sequence_by) -%}
    WITH ordered_data AS (
        SELECT
            {{ unique_key_concat }} AS unique_key,
            dbt_valid_from,
            dbt_valid_to,
            {{ sequence_by }},
            ROW_NUMBER() OVER (PARTITION BY {{ unique_key_concat }} ORDER BY {{ sequence_by }}) AS row_num
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
    ),
    updates AS (
        SELECT
            unique_key,
            current_valid_from,
            current_valid_to,
            COALESCE(next_valid_from, current_valid_to) AS corrected_valid_to
        FROM next_valid_from
    )
    MERGE INTO {{ target_relation }} AS t
    USING updates AS u
    ON {{ unique_key_concat }} = u.unique_key AND t.dbt_valid_from = u.current_valid_from
    WHEN MATCHED THEN
    UPDATE SET t.dbt_valid_to = u.corrected_valid_to
{%- endmacro %}

