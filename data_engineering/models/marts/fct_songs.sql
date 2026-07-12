-- One row per song per chart year: chart performance plus artist genre and
-- (where available) BPM. This is the main analysis table behind the vinyl
-- chart, decade dashboards, and genre wave visuals.

with songs as (

    select * from {{ ref('int_song_yearly') }}

),

tempo as (

    -- BPM file is song-level; aggregate defensively in case of duplicates
    select performer, title, min(bpm) as bpm
    from {{ ref('stg_artist_tempo') }}
    group by all

)

select
    s.chart_year,
    s.decade,
    s.performer,
    s.title,
    s.weeks_on_chart,
    s.peak_position,
    (s.peak_position = 1)  as is_number_one_hit,
    (s.weeks_on_chart = 1) as is_one_week_wonder,
    d.parent_genre,
    d.genre_from_override,
    d.artist_type,
    d.gender,
    d.artist_country,
    t.bpm,
    concat_ws('|', s.chart_year, s.performer, s.title) as song_year_key

from songs s
left join {{ ref('dim_artists') }} d using (performer)
left join tempo t
    on s.performer = t.performer
   and s.title = t.title
