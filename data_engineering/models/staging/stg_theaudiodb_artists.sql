-- One row per performer with TheAudioDB metadata. Same append-only raw file
-- pattern as MusicBrainz, so deduplicate defensively.

with source as (

    select * from {{ source('raw', 'theaudiodb_artist_metadata') }}

)

select
    performer,
    strGenre                      as genre,
    strStyle                      as style,
    strMood                       as mood,
    strGender                     as gender,
    strCountry                    as artist_origin,
    cast(intMembers as integer)   as member_count,
    cast(intFormedYear as integer) as formed_year,
    strLabel                      as record_label

from source
qualify row_number() over (partition by performer order by performer) = 1
