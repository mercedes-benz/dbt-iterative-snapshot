{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
-- Test that adapter-specific macros compile correctly
{% macro test_capabilities_compile() %}
    
    {% set capabilities = iterative_snapshot_get_adapter_capabilities() %}
    
    {% do log("Testing capability detection for " ~ target.type, info=True) %}
    {% do log("Supports clustering: " ~ capabilities.supports_clustering, info=True) %}
    {% do log("Supports partitioning: " ~ capabilities.supports_partitioning, info=True) %}
    {% do log("Preferred batch size: " ~ capabilities.preferred_batch_size, info=True) %}
    {% do log("Max batch size: " ~ capabilities.max_batch_size, info=True) %}
    
    -- Test user config helpers compile
    {% set test_config = {'performance_profile': 'balanced'} %}
    {% set smart_config = get_smart_config(test_config) %}
    {% do log("Smart config test passed", info=True) %}
    
    -- Test adapter-specific SQL generation
    {% set cluster_sql = iterative_snapshot_cluster_sql(['col1', 'col2']) %}
    {% do log("Cluster SQL for " ~ target.type ~ ": " ~ cluster_sql, info=True) %}
    
    {% do log("✅ All compilation tests passed for " ~ target.type, info=True) %}

{% endmacro %}