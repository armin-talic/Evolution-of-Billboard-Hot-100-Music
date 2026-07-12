-- Song-level BPM data from GetSongBPM. Partial coverage — long-career
-- artists only (~400 songs).

with source as (

    select * from {{ source('raw', 'artist_tempo_bpm') }}

)

select
    artist                as performer,
    song                  as title,
    cast(year as integer) as release_year,
    cast(bpm as integer)  as bpm

from source
where bpm is not null
