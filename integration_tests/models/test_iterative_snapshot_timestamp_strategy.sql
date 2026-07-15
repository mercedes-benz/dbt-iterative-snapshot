{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
{{ config(
    materialized='iterative_snapshot',
    strategy='timestamp',
    updated_at='file_datetime',
    sequence_by='batch_id',
    unique_key='user_id',
    invalidate_hard_deletes=true,
    batch_size=1,
    tags=['integration_test', 'timestamp_strategy']
) }}

SELECT 
    user_id,
    status,
    last_login,
    file_timestamp as file_datetime,
    batch_id
FROM {{ ref('sample_file_data') }}
WHERE batch_id <= 2