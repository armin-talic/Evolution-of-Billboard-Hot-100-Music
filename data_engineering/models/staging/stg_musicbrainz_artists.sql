-- One row per performer with MusicBrainz metadata.
-- The raw file is append-only (cache-and-resume fetch), so a performer could
-- in principle appear twice; deduplicate defensively keeping the first row.

with source as (

    select * from {{ source('raw', 'musicbrainz_artist_metadata') }}

)

select
    performer,
    genres  as genre_tags,
    country as artist_country,
    type    as artist_type

from source
qualify row_number() over (partition by performer order by performer) = 1
