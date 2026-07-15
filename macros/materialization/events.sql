{# SPDX-License-Identifier: MIT #}
{# Copyright (c) 2024 Mercedes-Benz Group AG #}

{#
  Event hook
  Called by the materialization when something noteworthy happens, so projects can plug in their own
  alerting (email, Slack, audit tables, ...). The default implementation only logs.

  event_type : 'duplicate_records' | 'out_of_order' | 'schema_change'
  model_name : snapshot model alias
  relation   : snapshot relation
  details    : dict with event-specific keys
      duplicate_records : sequence, duplicate_count, error_log_table
      out_of_order      : incoming_sequences, max_processed_sequence
      schema_change     : added, removed, not_in_check_cols

  To override, define e.g. `databricks__iterative_snapshot_on_event` or `default__iterative_snapshot_on_event`
  in your project and put your project first in the dispatch search order:

    dispatch:
      - macro_namespace: dbt_iterative_snapshot
        search_order: ['my_project', 'dbt_iterative_snapshot']
#}
{% macro iterative_snapshot_on_event(event_type, model_name, relation, details) %}
    {{ return(adapter.dispatch('iterative_snapshot_on_event', 'dbt_iterative_snapshot')(event_type, model_name, relation, details)) }}
{% endmacro %}

{% macro default__iterative_snapshot_on_event(event_type, model_name, relation, details) %}
    {%- do log("[iterative_snapshot event] " ~ event_type ~ " on " ~ relation ~ ": " ~ details, info=False) -%}
{% endmacro %}
