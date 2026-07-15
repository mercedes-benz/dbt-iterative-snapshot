{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
{{ config(
    materialized='iterative_snapshot',
    strategy='check',
    updated_at='file_datetime',
    sequence_by='file_name',
    unique_key=['uk1', 'uk2'],
    check_cols=['attribute1', 'attribute2'],
    invalidate_hard_deletes=true,
    batch_size=2,
    tags=['integration_test', 'basic_functionality']
) }}

SELECT 
    uk1,
    uk2,
    attribute1,
    attribute2,
    file_name,
    file_datetime
FROM {{ ref('edge_case_data') }}