

WITH parsed AS (
    SELECT
        appid,
        TRIM(name) AS game_name,
        TRIM(developer) AS developer,
        TRIM(publisher) AS publisher,
        score_rank,
        owners,
        average_forever AS avg_playtime_minutes,
        average_2weeks AS avg_playtime_2weeks,
        median_forever AS median_playtime_minutes,
        median_2weeks AS median_playtime_2weeks,
        ccu AS peak_concurrent_users,
        price,
        initialprice AS original_price,
        discount,
        tags,
        languages,
        genre,
        
        -- Fix: Clean owners string before parsing
        -- Remove commas and extract numbers
        REGEXP_EXTRACT(owners, '([0-9,]+)', 1) AS owners_min_str,
        REGEXP_EXTRACT(owners, '\\.\\. ([0-9,]+)', 1) AS owners_max_str,
        
        -- Fix: Remove commas and cast to BIGINT
        CAST(REPLACE(REGEXP_EXTRACT(owners, '([0-9,]+)', 1), ',', '') AS BIGINT) AS owners_min,
        CAST(REPLACE(REGEXP_EXTRACT(owners, '\\.\\. ([0-9,]+)', 1), ',', '') AS BIGINT) AS owners_max,
        
        -- Calculate estimated owners (midpoint of range)
        ROUND((
            CAST(REPLACE(REGEXP_EXTRACT(owners, '([0-9,]+)', 1), ',', '') AS BIGINT) + 
            CAST(REPLACE(REGEXP_EXTRACT(owners, '\\.\\. ([0-9,]+)', 1), ',', '') AS BIGINT)
        ) / 2, 0) AS estimated_owners,
        
        -- Price categories
        CASE 
            WHEN price = 0 THEN 'Free'
            WHEN price <= 10 THEN 'Budget ($0-10)'
            WHEN price > 10 AND price <= 30 THEN 'Mid-tier ($10-30)'
            WHEN price > 30 AND price <= 60 THEN 'Premium ($30-60)'
            ELSE 'Ultra-Tier ($60+)'
        END AS price_tier,
        
        -- Engagement categories
        CASE
            WHEN average_forever < 60 THEN 'Casual (<1h)'
            WHEN average_forever < 600 THEN 'Moderate (1-10h)'
            WHEN average_forever < 3000 THEN 'Engaged (10-50h)'
            ELSE 'Hardcore (50h+)'
        END AS engagement_tier,
        
        -- Discount flag
        CASE WHEN discount > 0 THEN TRUE ELSE FALSE END AS is_discounted,
        
        -- Parse tags into array for analysis
        SPLIT(tags, ',') AS tag_list,
        
        -- Parse languages
        SPLIT(languages, ',') AS language_list,
        
        -- Parse genres
        SPLIT(genre, ',') AS genre_list,
        
        -- Success indicators
        CASE 
            WHEN ROUND((
                CAST(REPLACE(REGEXP_EXTRACT(owners, '([0-9,]+)', 1), ',', '') AS BIGINT) + 
                CAST(REPLACE(REGEXP_EXTRACT(owners, '\\.\\. ([0-9,]+)', 1), ',', '') AS BIGINT)
            ) / 2, 0) > 1000000 AND average_forever > 600 THEN 'Hit'
            WHEN ROUND((
                CAST(REPLACE(REGEXP_EXTRACT(owners, '([0-9,]+)', 1), ',', '') AS BIGINT) + 
                CAST(REPLACE(REGEXP_EXTRACT(owners, '\\.\\. ([0-9,]+)', 1), ',', '') AS BIGINT)
            ) / 2, 0) > 100000 THEN 'Successful'
            WHEN ROUND((
                CAST(REPLACE(REGEXP_EXTRACT(owners, '([0-9,]+)', 1), ',', '') AS BIGINT) + 
                CAST(REPLACE(REGEXP_EXTRACT(owners, '\\.\\. ([0-9,]+)', 1), ',', '') AS BIGINT)
            ) / 2, 0) > 10000 THEN 'Moderate'
            ELSE 'Niche'
        END AS success_category

    FROM `workspace`.`raw_steam`.`raw_apps`
    WHERE name IS NOT NULL AND name != ''
)

SELECT * FROM parsed

