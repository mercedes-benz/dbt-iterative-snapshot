{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
-- Test every snapshot model processed data, so the other tests cannot pass on empty tables

{{ config(
    tags=['integration_test'],
    severity='error'
) }}

{% set snapshot_models = [
    'test_iterative_snapshot_basic',
    'test_iterative_snapshot_check_all',
    'test_iterative_snapshot_check_all_explicit',
    'test_iterative_snapshot_timestamp_strategy',
    'test_out_of_order_data'
] %}

{% for model_name in snapshot_models %}
SELECT '{{ model_name }}' AS empty_model
WHERE NOT EXISTS (SELECT 1 FROM {{ ref(model_name) }})
{% if not loop.last %}UNION ALL{% endif %}
{% endfor %}
