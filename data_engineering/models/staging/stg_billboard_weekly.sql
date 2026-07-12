-- Weekly Hot 100 entries with typed columns and derived time attributes
-- (chart year, decade, new-entry flag).

with source as (

    select * from {{ source('raw', 'billboard_hot100_weekly') }}

)

select
    cast(chart_week as date)          as chart_week,
    cast(current_week as integer)     as chart_position,
    title,
    performer,
    cast(last_week as integer)        as previous_week_position,
    cast(peak_pos as integer)         as peak_position_to_date,
    cast(wks_on_chart as integer)     as weeks_on_chart_to_date,
    year(cast(chart_week as date))    as chart_year,
    concat(cast(floor(year(cast(chart_week as date)) / 10) * 10 as integer), 's')
                                      as decade,
    (last_week is null)               as is_new_entry,
    concat_ws('|', chart_week, performer, title) as chart_entry_key

from source
