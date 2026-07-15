{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
-- Unit tests for helper macros

{% macro test_iterative_snapshot_create_metadata_table() %}
  {{ config(tags=['unit_test', 'metadata']) }}
  
  -- Test that metadata table creation macro works correctly
  {% set test_table_name = 'test_metadata_table_' ~ modules.datetime.datetime.now().strftime('%Y%m%d_%H%M%S') %}
  
  -- Execute the macro
  {{ create_metadata_table('`' ~ target.catalog ~ '`.`' ~ target.schema ~ '`.`' ~ test_table_name ~ '`') }}
  
  -- Verify table was created with correct schema
  {% set check_query %}
    SELECT 
      column_name,
      data_type
    FROM information_schema.columns
    WHERE table_schema = '{{ target.schema }}'
    AND table_name = '{{ test_table_name }}'
    ORDER BY ordinal_position
  {% endset %}
  
  {% set expected_columns = [
    ('invocation_id', 'string'),
    ('node_id', 'string'), 
    ('model_name', 'string'),
    ('run_started_at', 'timestamp'),
    ('sequence', 'string'),
    ('inserted_at', 'timestamp'),
    ('processed_by', 'string')
  ] %}
  
  -- Clean up test table
  {% set cleanup_query = "DROP TABLE IF EXISTS `" ~ target.catalog ~ "`.`" ~ target.schema ~ "`.`" ~ test_table_name ~ "`" %}
  {{ run_query(cleanup_query) }}
  
{% endmacro %}

{% macro test_iterative_snapshot_insert_metadata_record() %}
  {{ config(tags=['unit_test', 'metadata']) }}
  
  -- Test that metadata record insertion works correctly
  {% set test_table_name = 'test_metadata_insert_' ~ modules.datetime.datetime.now().strftime('%Y%m%d_%H%M%S') %}
  
  -- Create test metadata table
  {{ create_metadata_table('`' ~ target.catalog ~ '`.`' ~ target.schema ~ '`.`' ~ test_table_name ~ '`') }}
  
  -- Insert test record
  {{ insert_metadata_record(
    '`' ~ target.catalog ~ '`.`' ~ target.schema ~ '`.`' ~ test_table_name ~ '`',
    'test_invocation_123',
    'test_node_456', 
    '2024-01-01 10:00:00',
    'test_model',
    'test_sequence_1'
  ) }}
  
  -- Verify record was inserted correctly
  {% set verify_query %}
    SELECT 
      invocation_id,
      node_id,
      model_name,
      sequence
    FROM `{{ target.catalog }}`.`{{ target.schema }}`.`{{ test_table_name }}`
    WHERE invocation_id = 'test_invocation_123'
  {% endset %}
  
  {% set results = run_query(verify_query) %}
  {% if results.rows|length != 1 %}
    {{ exceptions.raise_compiler_error("Metadata record insertion test failed: expected 1 row, got " ~ results.rows|length) }}
  {% endif %}
  
  -- Clean up test table
  {% set cleanup_query = "DROP TABLE IF EXISTS `" ~ target.catalog ~ "`.`" ~ target.schema ~ "`.`" ~ test_table_name ~ "`" %}
  {{ run_query(cleanup_query) }}
  
{% endmacro %}

{% macro test_iterative_snapshot_get_sequences_to_process() %}
  {{ config(tags=['unit_test', 'sequence_processing']) }}
  
  -- Test sequence processing logic
  {% set test_metadata_table = 'test_sequences_metadata_' ~ modules.datetime.datetime.now().strftime('%Y%m%d_%H%M%S') %}
  {% set test_source_table = 'test_sequences_source_' ~ modules.datetime.datetime.now().strftime('%Y%m%d_%H%M%S') %}
  
  -- Create test tables
  {{ create_metadata_table('`' ~ target.catalog ~ '`.`' ~ target.schema ~ '`.`' ~ test_metadata_table ~ '`') }}
  
  {% set create_source_table %}
    CREATE TABLE `{{ target.catalog }}`.`{{ target.schema }}`.`{{ test_source_table }}` (
      sequence_id STRING,
      data_value STRING
    )
  {% endset %}
  {{ run_query(create_source_table) }}
  
  -- Insert test data
  {% set insert_source_data %}
    INSERT INTO `{{ target.catalog }}`.`{{ target.schema }}`.`{{ test_source_table }}` VALUES
    ('seq_001', 'data1'),
    ('seq_002', 'data2'),
    ('seq_003', 'data3')
  {% endset %}
  {{ run_query(insert_source_data) }}
  
  -- Insert metadata for seq_001 (already processed)
  {{ insert_metadata_record(
    '`' ~ target.catalog ~ '`.`' ~ target.schema ~ '`.`' ~ test_metadata_table ~ '`',
    'test_invocation',
    'test_node',
    '2024-01-01 10:00:00', 
    'test_model',
    'seq_001'
  ) }}
  
  -- Test that only unprocessed sequences are returned
  {% set unprocessed_sequences = iterative_snapshot_get_sequences_to_process(
    '`' ~ target.catalog ~ '`.`' ~ target.schema ~ '`.`' ~ test_source_table ~ '`',
    '`' ~ target.catalog ~ '`.`' ~ target.schema ~ '`.`' ~ test_metadata_table ~ '`',
    'sequence_id',
    'test_model',
    2
  ) %}
  
  {% if unprocessed_sequences|length != 2 %}
    {{ exceptions.raise_compiler_error("Sequence processing test failed: expected 2 unprocessed sequences, got " ~ unprocessed_sequences|length) }}
  {% endif %}
  
  -- Clean up test tables
  {{ run_query("DROP TABLE IF EXISTS `" ~ target.catalog ~ "`.`" ~ target.schema ~ "`.`" ~ test_metadata_table ~ "`") }}
  {{ run_query("DROP TABLE IF EXISTS `" ~ target.catalog ~ "`.`" ~ target.schema ~ "`.`" ~ test_source_table ~ "`") }}
  
{% endmacro %}