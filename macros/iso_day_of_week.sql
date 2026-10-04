{#-
    ISO day of week: Monday = 1 ... Sunday = 7.
    Each warehouse numbers weekdays differently, so the SQL is chosen per adapter.
-#}
{% macro iso_day_of_week(date_expr) -%}
    {{ return(adapter.dispatch('iso_day_of_week')(date_expr)) }}
{%- endmacro %}

{% macro default__iso_day_of_week(date_expr) -%}
    extract(isodow from {{ date_expr }})
{%- endmacro %}

{% macro bigquery__iso_day_of_week(date_expr) -%}
    {#- BigQuery's DAYOFWEEK is Sunday = 1 ... Saturday = 7 -#}
    mod(extract(dayofweek from {{ date_expr }}) + 5, 7) + 1
{%- endmacro %}
