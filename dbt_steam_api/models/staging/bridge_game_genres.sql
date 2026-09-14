{{ config(materialized='table') }}

WITH exploded AS (
    SELECT
        appid,
        game_name,
        estimated_owners,
        avg_playtime_minutes,
        price,
        success_category,
        TRIM(g) AS genre
    FROM {{ ref('stg_steam_apps') }},
    LATERAL EXPLODE(genre_list) AS t(g)
)

SELECT
    appid,
    game_name,
    genre,
    estimated_owners,
    avg_playtime_minutes,
    price,
    success_category,
    COUNT(*) OVER (PARTITION BY genre) AS games_in_genre
FROM exploded
WHERE genre IS NOT NULL AND genre != ''