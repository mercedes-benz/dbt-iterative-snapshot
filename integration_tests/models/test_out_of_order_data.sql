{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
{{ config(
    materialized='iterative_snapshot',
    strategy='check',
    updated_at='file_datetime',
    sequence_by='file_name',
    unique_key='user_id',
    check_cols=['status', 'last_login'],
    invalidate_hard_deletes=true,
    batch_size=1,
    tags=['integration_test', 'out_of_order']
) }}

-- This model tests out-of-order file processing
-- Files arrive in sequence: file_003.csv, then file_001.csv, then file_002.csv
-- The system should detect and reprocess when earlier files arrive late
WITH ordered_data AS (
    SELECT 
        user_id,
        status,
        last_login,
        file_timestamp as file_datetime,
        file_name,
        -- Simulate out-of-order arrival by processing file_003 first
        CASE 
            WHEN file_name = 'file_003.csv' THEN 1
            WHEN file_name = 'file_001.csv' THEN 2  -- This arrives late
            WHEN file_name = 'file_002.csv' THEN 3
        END as processing_order
    FROM {{ ref('sample_file_data') }}
)

SELECT 
    user_id,
    status,
    last_login,
    file_datetime,
    file_name
FROM ordered_data
ORDER BY processing_order