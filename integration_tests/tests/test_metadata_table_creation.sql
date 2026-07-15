{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
-- Test that metadata tables are created correctly

{{ config(
    tags=['integration_test', 'metadata'],
    severity='error'
) }}

WITH metadata_check AS (
    SELECT COUNT(*) as table_count
    FROM information_schema.tables 
    WHERE table_schema = '{{ var("metadata_schema") }}'
    AND table_name = 'iterative_snapshot_metadata'
)

SELECT *
FROM metadata_check
WHERE table_count = 0  -- Should be empty if metadata table exists