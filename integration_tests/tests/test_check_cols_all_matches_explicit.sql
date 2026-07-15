{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
-- Test check_cols='all' produces the same SCD2 history as listing every column explicitly

{{ config(
    tags=['integration_test', 'check_cols_all'],
    severity='error'
) }}

{#- Hard deletes are stamped with the processing time (snapshot_get_time), which differs between the two models,
    so their validity timestamps are excluded from the comparison -#}
{% set compare_cols -%}
    uk1, uk2, attribute1, attribute2, file_name, file_datetime, dbt_change_type,
    CASE WHEN dbt_change_type = 'delete' THEN NULL ELSE dbt_valid_from END AS dbt_valid_from,
    CASE WHEN dbt_change_type = 'delete' THEN NULL ELSE dbt_valid_to END AS dbt_valid_to
{%- endset %}

WITH check_all AS (
    SELECT {{ compare_cols }} FROM {{ ref('test_iterative_snapshot_check_all') }}
),

explicit AS (
    SELECT {{ compare_cols }} FROM {{ ref('test_iterative_snapshot_check_all_explicit') }}
),

only_in_check_all AS (
    SELECT 'only_in_check_all' AS diff, * FROM (SELECT * FROM check_all EXCEPT ALL SELECT * FROM explicit)
),

only_in_explicit AS (
    SELECT 'only_in_explicit' AS diff, * FROM (SELECT * FROM explicit EXCEPT ALL SELECT * FROM check_all)
),

empty_history AS (
    -- Guard against both models being empty, which would make the comparison pass trivially
    SELECT 'empty_history' AS diff, {{ compare_cols }}
    FROM (SELECT NULL AS uk1, NULL AS uk2, NULL AS attribute1, NULL AS attribute2, NULL AS file_name,
                 NULL AS file_datetime, NULL AS dbt_valid_from, NULL AS dbt_valid_to, NULL AS dbt_change_type)
    WHERE NOT EXISTS (SELECT 1 FROM check_all)
)

-- This should return no rows if both histories are identical and non-empty
SELECT * FROM only_in_check_all
UNION ALL
SELECT * FROM only_in_explicit
UNION ALL
SELECT * FROM empty_history
