
  
    
        create or replace table `workspace`.`raw_steam_marts`.`mart_valve_recommendations`
      
      
    using delta
  
      
      
      
      
      
      
      
      
      as
      -- ============================================
-- VALVE GAME DEVELOPMENT RECOMMENDATIONS
-- Uses bridge tables for many-to-many analysis
-- ============================================

-- 1. GENRE PERFORMANCE (from bridge table)
WITH genre_analysis AS (
    SELECT
        genre,
        COUNT(DISTINCT appid) AS game_count,
        ROUND(AVG(price), 2) AS avg_price,
        ROUND(AVG(estimated_owners), 0) AS avg_owners,
        ROUND(AVG(avg_playtime_minutes), 0) AS avg_playtime,
        SUM(CASE WHEN success_category = 'Hit' THEN 1 ELSE 0 END) AS hit_games,
        ROUND(100.0 * SUM(CASE WHEN success_category = 'Hit' THEN 1 ELSE 0 END) / COUNT(*), 2) AS hit_rate_pct
    FROM `workspace`.`raw_steam_staging`.`bridge_game_genres`
    WHERE genre IS NOT NULL AND genre != ''
    GROUP BY genre
),

-- 2. TAG PERFORMANCE (from bridge table)
tag_analysis AS (
    SELECT
        tag,
        COUNT(DISTINCT appid) AS game_count,
        ROUND(AVG(estimated_owners), 0) AS avg_owners,
        ROUND(AVG(price), 2) AS avg_price,
        SUM(CASE WHEN success_category = 'Hit' THEN 1 ELSE 0 END) AS hit_games,
        ROUND(100.0 * SUM(CASE WHEN success_category = 'Hit' THEN 1 ELSE 0 END) / COUNT(*), 2) AS hit_rate_pct
    FROM `workspace`.`raw_steam_staging`.`bridge_game_tags`
    WHERE tag IS NOT NULL AND tag != ''
    GROUP BY tag
    HAVING COUNT(DISTINCT appid) >= 5  -- Only tags with 5+ games
),

-- 3. LANGUAGE PERFORMANCE (from bridge table)
language_analysis AS (
    SELECT
        language,
        COUNT(DISTINCT appid) AS game_count,
        ROUND(AVG(estimated_owners), 0) AS avg_owners,
        ROUND(AVG(price), 2) AS avg_price,
        SUM(CASE WHEN success_category = 'Hit' THEN 1 ELSE 0 END) AS hit_games,
        ROUND(100.0 * SUM(CASE WHEN success_category = 'Hit' THEN 1 ELSE 0 END) / COUNT(*), 2) AS hit_rate_pct
    FROM `workspace`.`raw_steam_staging`.`bridge_game_languages`
    WHERE language IS NOT NULL AND language != ''
    GROUP BY language
    HAVING COUNT(DISTINCT appid) >= 5
),

-- 4. PRICE TIER PERFORMANCE (from fact table - single value per game)
price_analysis AS (
    SELECT
        price_tier,
        COUNT(*) AS game_count,
        ROUND(AVG(estimated_owners), 0) AS avg_owners,
        ROUND(AVG(discount), 0) AS avg_discount,
        SUM(CASE WHEN success_category IN ('Hit', 'Successful') THEN 1 ELSE 0 END) AS successful_games,
        ROUND(100.0 * SUM(CASE WHEN success_category IN ('Hit', 'Successful') THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate_pct
    FROM `workspace`.`raw_steam_staging`.`fct_game_performance`
    GROUP BY price_tier
),

-- 5. ENGAGEMENT PERFORMANCE (from fact table - single value per game)
engagement_analysis AS (
    SELECT
        engagement_tier,
        COUNT(*) AS game_count,
        ROUND(AVG(price), 2) AS avg_price,
        ROUND(AVG(peak_concurrent_users), 0) AS avg_peak_ccu
    FROM `workspace`.`raw_steam_staging`.`fct_game_performance`
    GROUP BY engagement_tier
)

-- ============================================
-- FINAL OUTPUT: Separate sections for clarity
-- ============================================

-- Genre recommendations
SELECT
    'GENRE' AS category,
    genre AS item,
    hit_rate_pct AS score,
    CONCAT(
        'Genre "', genre, '" has ', hit_rate_pct, 
        '% hit rate (', hit_games, '/', game_count, ' games). ',
        'Avg price: $', avg_price, '. Avg owners: ', avg_owners,
        CASE WHEN hit_rate_pct >= 30 THEN ' ⭐ STRONG RECOMMENDATION'
             WHEN hit_rate_pct >= 15 THEN ' ✓ MODERATE POTENTIAL'
             ELSE ' ▪ NICHE MARKET' END
    ) AS recommendation
FROM genre_analysis
WHERE hit_rate_pct > 0

UNION ALL

-- Tag recommendations
SELECT
    'TAG' AS category,
    tag AS item,
    hit_rate_pct AS score,
    CONCAT(
        'Tag "', tag, '" appears in ', game_count, 
        ' games with ', hit_rate_pct, '% hit rate. ',
        'Avg owners: ', avg_owners
    ) AS recommendation
FROM tag_analysis
WHERE hit_rate_pct > 0

UNION ALL

-- Language recommendations
SELECT
    'LANGUAGE' AS category,
    language AS item,
    hit_rate_pct AS score,
    CONCAT(
        'Language "', language, '" in ', game_count, 
        ' games with ', hit_rate_pct, '% hit rate. ',
        CASE WHEN hit_rate_pct >= 30 THEN 'Prioritize localization!'
             WHEN hit_rate_pct >= 15 THEN 'Include if budget allows.'
             ELSE 'Consider post-launch.' END
    ) AS recommendation
FROM language_analysis
WHERE hit_rate_pct > 0

UNION ALL

-- Price tier recommendations
SELECT
    'PRICE' AS category,
    price_tier AS item,
    success_rate_pct AS score,
    CONCAT(
        'Price tier "', price_tier, '": ', success_rate_pct,
        '% success (', successful_games, '/', game_count, '). ',
        'Avg owners: ', avg_owners,
        CASE WHEN avg_discount > 20 THEN ' Heavy discounting.' ELSE ' Minimal discounting.' END
    ) AS recommendation
FROM price_analysis

UNION ALL

-- Engagement recommendations
SELECT
    'ENGAGEMENT' AS category,
    engagement_tier AS item,
    avg_peak_ccu AS score,
    CONCAT(
        'Games with "', engagement_tier, '" engagement: ',
        avg_peak_ccu, ' avg peak CCU. ',
        'Avg price: $', avg_price
    ) AS recommendation
FROM engagement_analysis
  