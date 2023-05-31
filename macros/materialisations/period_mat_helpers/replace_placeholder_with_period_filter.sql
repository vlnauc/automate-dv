/*
 * Copyright (c) Business Thinking Ltd. 2019-2023
 * This software includes code developed by the dbtvault Team at Business Thinking Ltd. Trading as Datavault
 */

{%- macro replace_placeholder_with_period_filter(core_sql, timestamp_field, start_timestamp, stop_timestamp, offset, period) -%}

    {% set macro = adapter.dispatch('replace_placeholder_with_period_filter',
                                    'dbtvault')(core_sql=core_sql,
                                                timestamp_field=timestamp_field,
                                                start_timestamp=start_timestamp,
                                                stop_timestamp=stop_timestamp,
                                                offset=offset,
                                                period=period) %}
    {% do return(macro) %}
{%- endmacro %}


{% macro default__replace_placeholder_with_period_filter(core_sql, timestamp_field, start_timestamp, stop_timestamp, offset, period) %}

    {%- set period_filter -%}
        (TO_TIMESTAMP({{ timestamp_field }})
        >= DATE_TRUNC('{{ period }}', TO_TIMESTAMP('{{ start_timestamp }}') + INTERVAL '{{ offset }} {{ period }}') AND
             TO_TIMESTAMP({{ timestamp_field }}) < DATE_TRUNC('{{ period }}', TO_TIMESTAMP('{{ start_timestamp }}') + INTERVAL '{{ offset }} {{ period }}' + INTERVAL '1 {{ period }}'))
      AND (TO_TIMESTAMP({{ timestamp_field }}) >= TO_TIMESTAMP('{{ start_timestamp }}'))
    {%- endset -%}
    {%- set filtered_sql = core_sql | replace("__PERIOD_FILTER__", period_filter) -%}

    {% do return(filtered_sql) %}
{% endmacro %}


{% macro bigquery__replace_placeholder_with_period_filter(core_sql, timestamp_field, start_timestamp, stop_timestamp, offset, period) %}
    {%- if period is in ['day', 'week', 'month', 'quarter', 'year'] -%}
        {%- set timestamp_field_type = 'DATE' -%}
    {%- elif period is in ['millisecond', 'microsecond', 'second', 'minute', 'hour'] -%}
        {%- set timestamp_field_type = 'TIMESTAMP' -%}
    {%- else -%}
        {%- set timestamp_field_type = 'DATE' -%}
    {%- endif -%}

    {%- set period_filter -%}
            ({{ timestamp_field_type }}({{ timestamp_field }}) >= DATE_TRUNC({{ timestamp_field_type }}_ADD( {{ timestamp_field_type }}('{{ start_timestamp }}'), INTERVAL {{ offset }} {{ period }}), {{ period }} ) AND
             {{ timestamp_field_type }}({{ timestamp_field }}) < DATE_TRUNC({{ timestamp_field_type }}_ADD(TIMESTAMP_ADD( {{ timestamp_field_type }}('{{ start_timestamp }}'), INTERVAL {{ offset }} {{ period }}), INTERVAL 1 {{ period }}), {{ period }} )
      AND TIMESTAMP({{ timestamp_field }}) >= TIMESTAMP('{{ start_timestamp }}'))
    {%- endset -%}

    {%- set filtered_sql = core_sql | replace("__PERIOD_FILTER__", period_filter) -%}

    {% do return(filtered_sql) %}
{% endmacro %}


{% macro sqlserver__replace_placeholder_with_period_filter(core_sql, timestamp_field, start_timestamp, stop_timestamp, offset, period) %}
    {%- if period is in ['microsecond', 'millisecond', 'second'] -%}
        {%- set error_message -%}
        'This datepart ({{ period }}) is too small and cannot be used for this purpose in MS SQL Server, consider using a different datepart value (e.g. day).
         Vault_insert_by materialisations are not intended for this purpose,
        please see https://dbtvault.readthedocs.io/en/latest/materialisations/'
        {%- endset -%}

        {{- exceptions.raise_compiler_error(error_message) -}}
    {%- endif -%}
    {#  MSSQL cannot CAST datetime2 strings with more than 7 decimal places #}
    {% set start_timestamp_mssql = start_timestamp[0:27] %}
    {%- set period_filter -%}
            (CAST({{ timestamp_field }} AS DATETIME2) >= DATEADD({{ period }}, DATEDIFF({{ period }}, 0, DATEADD({{ period }}, {{ offset }}, CAST('{{ start_timestamp_mssql }}' AS DATETIME2))), 0) AND
             CAST({{ timestamp_field }} AS DATETIME2) < DATEADD({{ period }}, 1, DATEADD({{ period }}, {{ offset }}, CAST('{{ start_timestamp_mssql }}' AS DATETIME2)))
      AND (CAST({{ timestamp_field }} AS DATETIME2) >= CAST('{{ start_timestamp_mssql }}' AS DATETIME2)))
    {%- endset -%}

    {%- set filtered_sql = core_sql | replace("__PERIOD_FILTER__", period_filter) -%}

    {% do return(filtered_sql) %}
{% endmacro %}


{% macro postgres__replace_placeholder_with_period_filter(core_sql, timestamp_field, start_timestamp, stop_timestamp, offset, period) %}

    {%- set period_filter -%}
        {{ timestamp_field }}::TIMESTAMP >= DATE_TRUNC('{{ period }}', TIMESTAMP '{{ start_timestamp }}' + INTERVAL '{{ offset }} {{ period }}')
        AND {{ timestamp_field }}::TIMESTAMP < DATE_TRUNC('{{ period }}', TIMESTAMP '{{ start_timestamp }}' + INTERVAL '{{ offset }} {{ period }}' + INTERVAL '1 {{ period }}')
        AND {{ timestamp_field }}::TIMESTAMP >= TIMESTAMP '{{ start_timestamp }}'
    {%- endset -%}
    {%- set filtered_sql = core_sql | replace("__PERIOD_FILTER__", period_filter) -%}

    {% do return(filtered_sql) %}
{% endmacro %}
