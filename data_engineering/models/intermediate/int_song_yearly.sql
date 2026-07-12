-- Weekly chart entries rolled up to song/year grain.

select
    chart_year,
    decade,
    performer,
    title,
    max(weeks_on_chart_to_date) as weeks_on_chart,
    min(chart_position)         as peak_position

from {{ ref('stg_billboard_weekly') }}
where chart_year >= 1960
group by all
