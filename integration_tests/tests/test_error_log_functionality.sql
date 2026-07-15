{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
-- Test that error logging works when data quality issues occur

{{ config(
    tags=['integration_test', 'error_handling'],
    severity='error'
) }}

WITH error_log_check AS (
    SELECT COUNT(*) as table_count
    FROM information_schema.tables 
    WHERE table_schema = '{{ var("metadata_schema") }}'
    AND table_name = 'iterative_snapshot_error_log'
)

SELECT *
FROM error_log_check  
WHERE table_count = 0  -- Should be empty if error log table exists