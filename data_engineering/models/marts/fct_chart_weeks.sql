-- Weekly chart grain materialized for BI tools (Power BI reads this
-- directly for timeline / wave visuals). 1960 onwards, matching the
-- project's analysis window.

select
    chart_week,
    chart_year,
    decade,
    performer,
    title,
    chart_position,
    previous_week_position,
    peak_position_to_date,
    weeks_on_chart_to_date,
    is_new_entry

from {{ ref('stg_billboard_weekly') }}
where chart_year >= 1960
