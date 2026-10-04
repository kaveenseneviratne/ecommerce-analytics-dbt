{#- Division that returns null instead of erroring when the denominator is zero. -#}
{% macro safe_divide(numerator, denominator) -%}
    ({{ numerator }}) / nullif({{ denominator }}, 0)
{%- endmacro %}
