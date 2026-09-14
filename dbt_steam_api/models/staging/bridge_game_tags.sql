{{ config(materialized='table') }}

WITH exploded AS (
    SELECT
        appid,
        game_name,
        estimated_owners,
        avg_playtime_minutes,
        price,
        success_category,
        TRIM(tag) AS tag
    FROM {{ ref('stg_steam_apps') }},
    LATERAL EXPLODE(tag_list) AS t(tag)
)

SELECT
    appid,
    game_name,
    tag,
    estimated_owners,
    avg_playtime_minutes,
    price,
    success_category,
    COUNT(*) OVER (PARTITION BY tag) AS games_with_tag
FROM exploded
WHERE tag IS NOT NULL AND tag != ''