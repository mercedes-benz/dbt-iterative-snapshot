{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}
{%- materialization iterative_snapshot, adapter='databricks' -%}

{%- set config = model['config'] -%}
{%- set strategy_name = config.get('strategy') -%}
{%- set check_cols_config = config.get('check_cols') -%}
{# Support check_cols='all' or timestamp strategy (no check_cols) - auto-expand to all columns in the source query #}
{%- if check_cols_config == 'all' or (check_cols_config is none and strategy_name == 'timestamp') -%}
    {%- set check_cols_config = get_columns_in_query(model['compiled_code']) -%}
{%- endif -%}
{%- set unique_key = config.get('unique_key') -%}
{%- set updated_at = config.get('updated_at') -%}
{%- set target_table = model.get('alias', model.get('name')) -%}
{%- set grant_config = config.get('grants') -%}
{%- set sequence_by = config.get('sequence_by') -%}  
{%- set invalidate_hard_deletes = config.get('invalidate_hard_deletes') -%}
{# Metadata table naming: use config override if provided, otherwise use default with optional prefix #}
{%- set dev_prefix = var('dev_table_prefix', '') -%}
{%- set disable_prefix = var('disable_dev_table_prefix', false) -%}
{%- set metadata_schema = var('metadata_schema', 'dbt_iterative_snapshot_metadata') -%}
{%- set base_metadata_name = config.get('metadata_table_name', 'iterative_snapshot_metadata') -%}
{%- set base_error_log_name = config.get('error_log_table_name', 'iterative_snapshot_error_log') -%}
{%- if dev_prefix and not disable_prefix -%}
    {%- set metadata_table_name = dev_prefix ~ '_' ~ target.schema ~ '_' ~ base_metadata_name -%}
    {%- set error_log_table_name = dev_prefix ~ '_' ~ target.schema ~ '_' ~ base_error_log_name -%}
{%- else -%}
    {%- set metadata_table_name = base_metadata_name -%}
    {%- set error_log_table_name = base_error_log_name -%}
{%- endif -%}
{%- set qualified_metadata_table = '`' ~ target.catalog ~ '`.`' ~ metadata_schema ~ '`.`' ~ metadata_table_name ~ '`' -%}
{%- set qualified_error_log_table = '`' ~ target.catalog ~ '`.`' ~ metadata_schema ~ '`.`' ~ error_log_table_name ~ '`' -%}



{# dbt_scd_id : generates a hash based on updated_at+unique_key column #}
{%- if not updated_at -%}
    {{ exceptions.raise_compiler_error("ERROR: updated_at field is required. Please specify a timestamp column coming from the actual source of truth and not generated timestamps if backfilling is required in the future.") }}
{%- endif -%}


{%- if not sequence_by -%}
    {{ exceptions.raise_compiler_error("ERROR: sequence_by field is required. Please specify a column on which to sequence records,it should be monotonically increasing representation of the proper ordering of the source data") }}
{%- endif -%}


{# create schema if not exists #}
{%- do adapter.create_schema(api.Relation.create(database=target.database, schema=model.schema)) -%}


{# Create metadata table #}
{%- do dbt_iterative_snapshot.create_metadata_table(table_name=qualified_metadata_table) -%}
{%- do dbt_iterative_snapshot.create_error_log_table(table_name=qualified_error_log_table) -%}

{# Determine full-refresh mode: model config takes precedence over CLI flag #}
{%- set full_refresh_mode = flags.FULL_REFRESH -%}
{%- if config.get('full_refresh') is not none -%}
    {%- set full_refresh_mode = config.get('full_refresh') -%}
{%- endif -%}


{%- set strategy_macro = strategy_dispatch(strategy_name) -%}


{%- set target_relation_exists, target_relation = get_or_create_relation(
        database=model.database,
        schema=model.schema,
        identifier=target_table,
        type='table') -%}


{% set backing_relation_exists, backing_relation = get_or_create_relation(
        database=model.database,
        schema=model.schema,
        identifier=target_relation.identifier ~ '__snapshot_backing',
        type='table') -%}


{%- if not target_relation.is_table -%}
{%- do exceptions.relation_wrong_type(target_relation, 'table') -%}
{%- endif -%}


{# Full-refresh: drop snapshot table and clear its metadata so it is rebuilt from scratch.
   Historical rows whose sequence is no longer present in raw (outside the ~60-day window) are
   backed up first and restored after the rebuild so no SCD2 history is permanently lost. #}
{%- if full_refresh_mode and target_relation_exists -%}

    {# Step 1: Back up rows whose sequence is no longer available in the raw source #}
    {%- set fullrefresh_backup_relation = api.Relation.create(
            database=model.database,
            schema=model.schema,
            identifier=target_relation.identifier ~ '__fullrefresh_backup') -%}

    {%- do log("[Full Refresh] : Backing up historical rows no longer available in raw to " ~ fullrefresh_backup_relation ~ "...", info=True) -%}
    {%- set backup_historical_sql -%}
        CREATE OR REPLACE TABLE {{ fullrefresh_backup_relation }} AS
        SELECT * FROM {{ target_relation }}
        WHERE {{ sequence_by }} NOT IN (
            SELECT DISTINCT {{ sequence_by }} FROM ( {{ model['compiled_code'] }} )
        )
    {%- endset -%}
    {%- do run_query(backup_historical_sql) -%}

    {# Step 2: Drop the snapshot table and clear its metadata #}
    {%- do log("[Full Refresh] : Dropping existing snapshot table " ~ target_relation ~ "...", info=True) -%}
    {%- set drop_target_sql -%}
        DROP TABLE IF EXISTS {{ target_relation }}
    {%- endset -%}
    {%- do run_query(drop_target_sql) -%}

    {%- do log("[Full Refresh] : Clearing metadata entries for model '" ~ target_table ~ "' from " ~ qualified_metadata_table ~ "...", info=True) -%}
    {%- set delete_metadata_sql -%}
        DELETE FROM {{ qualified_metadata_table }} WHERE model_name = '{{ target_table }}'
    {%- endset -%}
    {%- do run_query(delete_metadata_sql) -%}

    {%- set target_relation_exists = False -%}
    {%- do log("[Full Refresh] : Snapshot table dropped and metadata cleared. Rebuilding from raw, then restoring historical backup.", info=True) -%}
{%- endif -%}


{# Create empty snapshot table #}
{%- if not target_relation_exists -%}
    {%- do log("[Snapshot table doesn't exist] : Creating empty Snapshot table... ", info=True) -%}
    {%- set strategy = strategy_macro(model, "snapshotted_data", "source_data", config, False) -%}
    {%- set sql_ = "select * from ( "    + model['compiled_code'] + "  ) WHERE 1=2"   -%}
    {%- set build_sql = dbt_iterative_snapshot.build_iterative_snapshot_table(strategy, sql_) -%}
    {%- set final_sql = create_table_as(False, this, build_sql) -%}
    {%- call statement('create empty snapshot table') -%}
    {{ final_sql }}
    {%- endcall -%}
    {# Use 'this' as target_relation — adapter cache may not reflect the new table yet #}
    {%- set target_relation = this -%}
{%- endif -%}




{%- if unique_key | is_list -%}
    {%- set handle_uk_nulls = [] -%}
    {%- for k in unique_key -%}
        {%- set _ = handle_uk_nulls.append("coalesce(" + k + ",'')") -%}
    {%- endfor -%}
    {%- set unique_key_concat = "concat_ws('-', "  + handle_uk_nulls | join(', ') + ")" -%}
{%- else -%}
    {%- set unique_key_concat = unique_key -%}
{%- endif -%}


{{ run_hooks(pre_hooks, inside_transaction=False) }}

{{ run_hooks(pre_hooks, inside_transaction=True) }}


-- Get unprocessed sequence:
 {%- if not target_relation_exists -%}
      {%- set unprocessed_sequence -%}
          SELECT DISTINCT {{ sequence_by }} as sequence_by
          FROM ( {{ model['compiled_code'] }} )
          ORDER BY sequence_by
      {%- endset -%}
  {%- else -%}
      {%- set unprocessed_sequence -%}
          SELECT DISTINCT {{ sequence_by }} as sequence_by
          FROM ( {{ model['compiled_code'] }} ) s
          LEFT JOIN {{ qualified_metadata_table }} m
              ON s.{{ sequence_by }} = m.sequence
              AND m.model_name = '{{ target_table }}'
          WHERE m.sequence IS NULL
          ORDER BY sequence_by
      {%- endset -%}
  {%- endif -%}


-- Create the list the unprocessed sequence to loop over
{%- set unprocessed_sequence_result = run_query(unprocessed_sequence) -%}
{%- set object_sequence = [] -%}
{%- for row in unprocessed_sequence_result.rows -%}
    {%- set _ = object_sequence.append(row['sequence_by']) -%}
{%- endfor -%}
{%- do log("Unprocessed object sequence: "  ~ object_sequence, info=True) -%}

{%- set strategy = strategy_macro(model, "snapshotted_data", "source_data", config, True) -%}

{# Initialize out_of_order flag #}
{%- set out_of_order = 0 -%}

{%- if object_sequence|length == 0 -%}
    {%- do log("No object to process...", info=True) -%}
{%- else -%}
--## handle out of order:
    -- Identify if sequences are out of order:
    -- Step 1: Get the maximum sequence which was processed.
    -- Step 2: Check if the minimum incoming sequence number is less than the value from (Step 1)
    {%- set get_max_target_object_sequence -%} 
            SELECT MAX(sequence) as sequence_by  FROM {{ qualified_metadata_table }}
            WHERE model_name = '{{ target_table }}'
    {%- endset -%}
    {%- set get_max_target_object_sequence = run_query(get_max_target_object_sequence).columns[0].values()[0] -%}


    {%- if get_max_target_object_sequence and load_cached_relation(target_relation) -%}
        {%- if object_sequence | min < get_max_target_object_sequence  -%}
            {% set out_of_order = 1 %}
            {%- do log("[Sequence Out Of Order] : Rebuilding snapshots...", info=True) -%}
            
            -- Rebuilding the snapshot:
            -- Step 1: Create a backup of snapshot table which are successor of OOO file and which doesn't exist in raw anymore.
            -- Step 2: Retrieve the list of sequences that are greater than or equal to the minimum incoming sequence.
            -- Step 3: Delete these sequences from the snapshot table.

            -- Step 1: Create a backing table:
            {% if invalidate_hard_deletes %}
                {% do log("[Step 1] : Creating snapshot backup : " ~ backing_relation, info=True) %}

                {% set backing_snapshot_table %}
                    CREATE OR REPLACE TABLE {{ backing_relation }} AS
                    SELECT * FROM {{ target_relation }}
                    WHERE {{ sequence_by }} > '{{ object_sequence[0] }}'
                    AND {{ sequence_by }} NOT IN (
                        SELECT DISTINCT {{ sequence_by }} as sequence_by
                        FROM ( {{ model['compiled_code'] }} 
                    ))
                {% endset %}

                {% set backing_snapshot_table = run_query(backing_snapshot_table) %}
            {% endif %}


            -- Step 2: Retrieve sequences to be reloaded
            {%- set sequence_to_reload -%}
                SELECT DISTINCT 
                sequence as sequence_by
                FROM {{ qualified_metadata_table }} s
                WHERE sequence >= '{{ object_sequence[0] }}'
                AND model_name = '{{ target_table }}'
            {%- endset -%}
            {%- set sequence_to_reload = run_query(sequence_to_reload) -%}

            -- Append the retrieved sequences to the object_sequence list
            {%- for row in sequence_to_reload.rows -%}
                {{ object_sequence.append(row['sequence_by']) }}
            {%- endfor -%}

            {%- do log("[Step 2] : Updated object sequence to process : "  ~ object_sequence | sort, info=True) -%}


            -- Step 3: Delete sequences from the snapshot table
            {%- do log("[Step 3] : Deleting the sequence from snapshot table...", info=True) -%}

            {%- set delete_sequence -%}
                    DELETE FROM {{ target_relation }}  WHERE  {{ sequence_by }} in (
                    SELECT DISTINCT  sequence FROM {{ qualified_metadata_table }} 
                WHERE sequence >= '{{ object_sequence[0] }}' 
                AND model_name = '{{ target_table }}' )
            {%- endset -%}
            {%- set delete_sequence = run_query(delete_sequence) -%}

        {%- endif -%}
    {%- endif -%}
{%- endif -%}

-- Create temporary staging table with all source data to avoid repeated model compilation
{%- if object_sequence|length > 0 -%}
    {%- if config.get('enable_temp_views', var('enable_temp_views', true)) -%}
        {%- set temp_source_table = target_relation.identifier ~ '__temp_source_' ~ invocation_id -%}
        
        {%- set create_temp_source -%}
            CREATE OR REPLACE TEMPORARY VIEW `{{ temp_source_table }}` 
            AS
            SELECT * FROM ( {{ model['compiled_code'] }} )
            WHERE {{ sequence_by }} IN ('{{ object_sequence | join("','") }}')
        {%- endset -%}
        {%- do run_query(create_temp_source) -%}
        {%- do log("Created temporary source view: " ~ temp_source_table, info=True) -%}
    {%- else -%}
        {%- do log("Skipping temporary views (enable_temp_views=false), will use source query directly", info=True) -%}
        {%- set temp_source_table = none -%}
    {%- endif -%}
{%- endif -%}

{%- for sequence in object_sequence | sort -%}

    {%- set source_data_sql -%}
        {%- if temp_source_table -%}
            `{{ temp_source_table }}`
        {%- else -%}
            ({{ model['compiled_code'] }})
        {%- endif -%}
    {%- endset -%}
    
    {%- if config.get('enable_data_quality_checks', var('enable_data_quality_checks', true)) -%}
        -- Find corrupt record
        {%- set corrupt_sql -%}
            SELECT 
                '{{ invocation_id }}' AS invocation_id,
                '{{ model.unique_id }}' AS node_id,
                '{{ target_table }}' AS model_name,
                CAST('{{ run_started_at }}' AS TIMESTAMP) AS run_started_at,
                '{{ sequence }}' AS sequence,
                {{ unique_key_concat }} as unique_key,
                {{ dbt_iterative_snapshot.create_json_from_struct() }} AS corrupted_record,
                current_timestamp() AS inserted_at,
                current_user() as processed_by
            FROM {{ source_data_sql }}
            WHERE {{ sequence_by }} = '{{ sequence }}'
            AND {{ unique_key_concat }} IN (
                SELECT {{ unique_key_concat }}
                FROM {{ source_data_sql }}
                WHERE {{ sequence_by }} = '{{ sequence }}'
                GROUP BY {{ unique_key_concat }} 
                HAVING count(*) > 1
            )
        {%- endset -%}

        {%- set check_corrupt_count =  "select count(*) from ( "    + corrupt_sql + "  )"  -%}
        {%- set check_corrupt = run_query(check_corrupt_count).columns[0].values()[0] -%}

        {%- if check_corrupt > 1 -%}
            {%- if config.get('enable_error_logging', var('enable_error_logging', true)) -%}
                {%- set insert_error_log_sql -%}
                    INSERT INTO {{ qualified_error_log_table }}
                    {{ corrupt_sql }}
                {%- endset -%}
                {{ run_query(insert_error_log_sql) }}  
            {%- endif -%}

            {%-  do log("WARNING: Corrupted record found. " ~ (config.get('enable_error_logging', var('enable_error_logging', true)) and "Logging to error log table " ~ qualified_error_log_table or "Error logging disabled."), info=True)  -%} 
        {%- endif -%}

        -- Don't include faulty record when data quality checks are enabled
        {%- set build_sql -%}
            SELECT * FROM {{ source_data_sql }} WHERE {{ sequence_by }} = '{{ sequence }}' 
            AND {{ unique_key_concat }} IN
                (SELECT {{ unique_key_concat }} FROM {{ source_data_sql }} WHERE {{ sequence_by }} = '{{ sequence }}'
                group by {{ unique_key_concat }} having count(*) = 1)
            {%- if out_of_order == 1 -%}
                    UNION
                SELECT {{ get_columns_in_query(model['compiled_code'])  | join(', ') }} FROM {{ backing_relation }}
                WHERE {{ sequence_by }} = '{{ sequence }}'
            {%- endif -%}
        {%- endset -%}
    {%- else -%}
        {%- do log("Skipping data quality checks (enable_data_quality_checks=" ~ config.get('enable_data_quality_checks', var('enable_data_quality_checks', true)) ~ ")", info=True) -%}
        -- Include all records when data quality checks are disabled
        {%- set build_sql -%}
            SELECT * FROM {{ source_data_sql }} WHERE {{ sequence_by }} = '{{ sequence }}'
            {%- if out_of_order == 1 -%}
                    UNION
                SELECT {{ get_columns_in_query(model['compiled_code'])  | join(', ') }} FROM {{ backing_relation }}
                WHERE {{ sequence_by }} = '{{ sequence }}'
            {%- endif -%}
        {%- endset -%}
    {%- endif -%}



    {%- set staging_table = dbt_iterative_snapshot.build_iterative_snapshot_staging_table(strategy, build_sql, target_relation, check_cols_config) -%}
    

-- this may no-op if the database does not require column expansion
    {%- do adapter.expand_target_column_types(from_relation=staging_table,
                                            to_relation=target_relation) -%}

    
    {%- set remove_columns = ['dbt_unique_key', 'DBT_UNIQUE_KEY'] -%}
    {%- if unique_key | is_list -%}
        {%- for key in strategy.unique_key %}
            {{ remove_columns.append('dbt_unique_key_' + loop.index|string) }}
            {{ remove_columns.append('DBT_UNIQUE_KEY_' + loop.index|string) }}
        {%- endfor -%}
    {%- endif -%}
    

    {%- set missing_columns = adapter.get_missing_columns(staging_table, target_relation)
                                | rejectattr('name', 'in', remove_columns)
                                | list -%}

    {%- do create_columns(target_relation, missing_columns) -%}

    {%- set source_columns = adapter.get_columns_in_relation(staging_table)
                                | rejectattr('name', 'in', remove_columns)
                                | list -%}

    {%- set quoted_source_columns = [] -%}
    {%- for column in source_columns -%}
        {%- do quoted_source_columns.append(adapter.quote(column.name)) -%}
    {%- endfor -%}


    {%- do log("Merging "  ~ sequence ~ "  to snapshot table "  ~  target_relation , info=True) -%}
    {%- set final_sql = dbt_iterative_snapshot.get_iterative_snapshot_merge_sql(
                target = target_relation,
                source = staging_table,
                insert_cols = quoted_source_columns
            ) -%}

    {%- set final_merge_sql = run_query(final_sql) -%}
    {%- do final_merge_sql.print_table() -%}


    {%- set insert_meta = dbt_iterative_snapshot.insert_metadata_record(
                table_name = qualified_metadata_table,
                invocation_id = invocation_id,
                node_id =  model.unique_id,
                run_started_at = run_started_at,
                model_name = target_table,
                sequence = sequence
            )
    -%}
    
{%- endfor -%}

-- Temporary view will be automatically cleaned up at session end

{# Full-refresh: restore historical rows that were outside the raw retention window #}
{%- if full_refresh_mode and fullrefresh_backup_relation is defined -%}
    {%- do log("[Full Refresh] : Restoring historical snapshot rows from " ~ fullrefresh_backup_relation ~ "...", info=True) -%}
    {%- set restore_historical_sql -%}
        INSERT INTO {{ target_relation }}
        SELECT * FROM {{ fullrefresh_backup_relation }}
    {%- endset -%}
    {%- do run_query(restore_historical_sql) -%}

    {# Restore metadata entries for the historical sequences so out-of-order detection remains correct #}
    {%- do log("[Full Refresh] : Restoring metadata entries for historical sequences...", info=True) -%}
    {%- set restore_metadata_sql -%}
        INSERT INTO {{ qualified_metadata_table }}
            (invocation_id, node_id, model_name, run_started_at, sequence, inserted_at, processed_by)
        SELECT DISTINCT
            '{{ invocation_id }}'                     AS invocation_id,
            '{{ model.unique_id }}'                   AS node_id,
            '{{ target_table }}'                      AS model_name,
            CAST('{{ run_started_at }}' AS TIMESTAMP) AS run_started_at,
            {{ sequence_by }}                         AS sequence,
            current_timestamp()                       AS inserted_at,
            current_user()                            AS processed_by
        FROM {{ fullrefresh_backup_relation }}
    {%- endset -%}
    {%- do run_query(restore_metadata_sql) -%}

    {%- do log("[Full Refresh] : Dropping historical backup table " ~ fullrefresh_backup_relation ~ "...", info=True) -%}
    {%- set drop_backup_sql -%}
        DROP TABLE IF EXISTS {{ fullrefresh_backup_relation }}
    {%- endset -%}
    {%- do run_query(drop_backup_sql) -%}
{%- endif -%}

{%- if config.get('enable_consistency_checks', var('enable_consistency_checks', true)) -%}
    -- Ensuring Consistency in SCD2 Validity Columns 
    -- Covers the scenario where a deleted UK becomes active again:
    {%- set inconsistency_count = dbt_iterative_snapshot.iterative_snapshot_check_for_inconsistencies(target_relation, unique_key_concat, sequence_by) -%}

    {%- if inconsistency_count | int > 0 -%}
        {%- set enforce_validity_columns = dbt_iterative_snapshot.get_enforce_validity_columns_sql(target_relation, unique_key_concat, sequence_by) -%}
        {%- set enforce_validity_columns = run_query(enforce_validity_columns) -%}
        {%- do log("Enforcing consistency on validity columns...", info=True) -%}
        {%- do enforce_validity_columns.print_table() -%}
    {%- endif -%}
{%- else -%}
    {%- do log("Skipping SCD2 consistency checks (enable_consistency_checks=" ~ config.get('enable_consistency_checks', var('enable_consistency_checks', true)) ~ ")", info=True) -%}
{%- endif -%}


{% if invalidate_hard_deletes  %}
    {% do log("Dropping backup snapshot table if exists...", info=True) %}
    {% set drop_backing_snapshot_table %}
        DROP TABLE IF EXISTS {{ backing_relation }}
    {% endset %}

    {% set drop_backing_snapshot_table = run_query(drop_backing_snapshot_table) %}
{% endif %}


{# In case there are no sequence to process #}
{%- set final_sql = "select 1 as iterative_snapshot"  -%}
{%- call statement('main') -%}
    {{ final_sql }}
{%- endcall -%}


{%- set should_revoke = should_revoke(target_relation_exists, full_refresh_mode=full_refresh_mode) -%}
{%- do apply_grants(target_relation, grant_config, should_revoke=should_revoke) -%}

{%- do persist_docs(target_relation, model) -%}

{%- if not target_relation_exists -%}
{%- do create_indexes(target_relation) -%}
{%- endif -%}

{{ run_hooks(post_hooks, inside_transaction=True) }}

{{ adapter.commit() }}

{%- if staging_table is defined -%}
    {%- do post_snapshot(staging_table) -%}
{%- endif -%}

{{ run_hooks(post_hooks, inside_transaction=False) }}

{{ return({'relations': [target_relation]}) }}

{%- endmaterialization -%}
