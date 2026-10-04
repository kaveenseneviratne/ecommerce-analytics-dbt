{#-
    Fails for rows where `column_name` is earlier than `other_column`.
    Rows where either value is null are ignored; null checks belong in not_null tests.

    Usage:
      columns:
        - name: delivered_at
          data_tests:
            - not_before:
                other_column: purchased_at
-#}
{% test not_before(model, column_name, other_column) %}

select *
from {{ model }}
where
    {{ column_name }} is not null
    and {{ other_column }} is not null
    and {{ column_name }} < {{ other_column }}

{% endtest %}
