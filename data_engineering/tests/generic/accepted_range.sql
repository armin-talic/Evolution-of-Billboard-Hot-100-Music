-- Generic range test (local replacement for dbt_utils.accepted_range, since
-- this machine cannot reach hub.getdbt.com). Fails on rows where the column
-- falls outside [min_value, max_value]; nulls pass — pair with not_null.
{% test accepted_range(model, column_name, min_value=none, max_value=none) %}

select *
from {{ model }}
where {{ column_name }} is not null
  and (
    {% if min_value is not none %} {{ column_name }} < {{ min_value }} {% else %} false {% endif %}
    or
    {% if max_value is not none %} {{ column_name }} > {{ max_value }} {% else %} false {% endif %}
  )

{% endtest %}
