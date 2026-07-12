-- One row per performer × cleaned genre tag, classified into a parent genre.
-- TheAudioDB genre is preferred, with MusicBrainz tags as fallback; tags are
-- exploded, normalized, filtered against the blocklist seed, then matched
-- against keyword rules (lowest matching priority wins).

with performers as (

    select distinct performer
    from {{ ref('stg_billboard_weekly') }}
    where chart_year >= 1960

),

merged as (

    select
        p.performer,
        coalesce(adb.genre, mb.genre_tags) as merged_genres
    from performers p
    left join {{ ref('stg_musicbrainz_artists') }} mb using (performer)
    left join {{ ref('stg_theaudiodb_artists') }} adb using (performer)
    where coalesce(adb.genre, mb.genre_tags) is not null

),

exploded as (

    select
        performer,
        lower(trim(unnest(string_split(merged_genres, ',')))) as tag
    from merged

),

normalized as (

    -- "rock & roll" / "rock and roll" variants collapse to plain rock
    select distinct
        performer,
        case
            when tag like '%rock & roll%' or tag like '%rock and roll%' then 'rock'
            else tag
        end as tag
    from exploded
    where tag <> ''

),

filtered as (

    select n.performer, n.tag
    from normalized n
    left join {{ ref('genre_tag_blocklist') }} b on n.tag = b.tag
    where b.tag is null

),

classified as (

    select
        f.performer,
        f.tag,
        k.parent_genre,
        row_number() over (
            partition by f.performer, f.tag
            order by k.priority
        ) as match_rank
    from filtered f
    left join {{ ref('genre_keyword_rules') }} k
        on position(k.keyword in f.tag) > 0

)

select
    performer,
    tag,
    coalesce(parent_genre, 'Other') as parent_genre

from classified
where match_rank = 1
