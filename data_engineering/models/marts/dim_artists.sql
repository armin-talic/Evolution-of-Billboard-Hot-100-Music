-- One row per performer with their dominant parent genre and API metadata.
--
-- Genre resolution order:
--   1. "force" override rules always win (e.g. Drake -> Hip-Hop)
--   2. otherwise the dominant genre across the artist's cleaned tags
--      (most frequent non-Other parent genre)
--   3. artists still landing on Other get "other_only" override rules
--   4. anything left stays Other

with performers as (

    select distinct performer
    from {{ ref('stg_billboard_weekly') }}
    where chart_year >= 1960

),

tag_counts as (

    select performer, parent_genre, count(*) as tag_count
    from {{ ref('int_artist_genre_tags') }}
    where parent_genre <> 'Other'
    group by all

),

dominant as (

    select performer, parent_genre
    from tag_counts
    qualify row_number() over (
        partition by performer
        order by tag_count desc, parent_genre
    ) = 1

),

override_matches as (

    select
        p.performer,
        o.rule_type,
        o.parent_genre,
        o.priority
    from performers p
    join {{ ref('artist_genre_overrides') }} o
        on regexp_matches(p.performer, o.performer_pattern)

),

best_force as (

    select performer, parent_genre
    from override_matches
    where rule_type = 'force'
    qualify row_number() over (partition by performer order by priority) = 1

),

best_other_only as (

    select performer, parent_genre
    from override_matches
    where rule_type = 'other_only'
    qualify row_number() over (partition by performer order by priority) = 1

),

resolved as (

    select
        p.performer,
        case
            when f.parent_genre is not null then f.parent_genre
            when coalesce(d.parent_genre, 'Other') = 'Other'
                 and o.parent_genre is not null then o.parent_genre
            else coalesce(d.parent_genre, 'Other')
        end as parent_genre,
        (f.parent_genre is not null
         or (coalesce(d.parent_genre, 'Other') = 'Other'
             and o.parent_genre is not null)) as genre_from_override
    from performers p
    left join dominant d using (performer)
    left join best_force f using (performer)
    left join best_other_only o using (performer)

)

select
    r.performer,
    r.parent_genre,
    r.genre_from_override,
    mb.artist_country,
    mb.artist_type,
    adb.gender,
    adb.mood,
    adb.style,
    adb.member_count,
    adb.formed_year,
    adb.record_label

from resolved r
left join {{ ref('stg_musicbrainz_artists') }} mb using (performer)
left join {{ ref('stg_theaudiodb_artists') }} adb using (performer)
