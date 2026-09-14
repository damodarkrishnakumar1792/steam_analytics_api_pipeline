{{ config(materialized='table') }}

SELECT
    appid,
    game_name,
    developer,
    publisher,
    price_tier,
    engagement_tier,
    success_category,
    tags,
    languages,
    genre,
    CURRENT_TIMESTAMP() AS loaded_at
FROM {{ ref('stg_steam_apps') }}
