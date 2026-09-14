

WITH exploded AS (
    SELECT
        appid,
        game_name,
        estimated_owners,
        avg_playtime_minutes,
        price,
        success_category,
        TRIM(lang) AS language
    FROM `workspace`.`raw_steam_staging`.`stg_steam_apps`,
    LATERAL EXPLODE(language_list) AS t(lang)
)

SELECT
    appid,
    game_name,
    language,
    estimated_owners,
    avg_playtime_minutes,
    price,
    success_category,
    COUNT(*) OVER (PARTITION BY language) AS games_with_language
FROM exploded
WHERE language IS NOT NULL AND language != ''