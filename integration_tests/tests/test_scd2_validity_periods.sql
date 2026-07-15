{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
-- Test SCD2 validity periods are logically consistent

{{ config(
    tags=['integration_test', 'scd2_validation'],
    severity='error'
) }}

WITH validity_check AS (
    SELECT 
        uk1,
        uk2,
        dbt_valid_from,
        dbt_valid_to,
        LEAD(dbt_valid_from) OVER (
            PARTITION BY uk1, uk2 
            ORDER BY dbt_valid_from
        ) as next_valid_from
    FROM {{ ref('test_iterative_snapshot_basic') }}
    WHERE dbt_change_type != 'delete'
),

gap_check AS (
    SELECT *
    FROM validity_check
    WHERE dbt_valid_to IS NOT NULL 
    AND next_valid_from IS NOT NULL
    AND dbt_valid_to != next_valid_from  -- Gap or overlap detected
)

-- This should return no rows if validity periods are consistent
SELECT *
FROM gap_check