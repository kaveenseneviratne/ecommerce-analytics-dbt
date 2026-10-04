{#-
    Cast a string to an integer, tolerating values exported as "3.0".
    A direct cast of '3.0' to INT64 fails in BigQuery, so go through numeric first.
-#}
{% macro to_int(column) -%}
    cast(cast({{ column }} as {{ dbt.type_numeric() }}) as {{ dbt.type_int() }})
{%- endmacro %}
