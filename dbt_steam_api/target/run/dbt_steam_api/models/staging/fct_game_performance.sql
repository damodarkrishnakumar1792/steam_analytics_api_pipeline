
  
    
        create or replace table `workspace`.`raw_steam_staging`.`fct_game_performance`
      
      
    using delta
  
      
      
      
      
      
      
      
      
      as
      SELECT
    appid,
    game_name,
    developer,
    publisher,
    genre,
    price_tier,
    engagement_tier,
    success_category,

    -- Financial metrics
    price,
    original_price,
    COALESCE(discount, 0) AS discount,
    estimated_owners,
    ROUND(price * estimated_owners, 2) AS estimated_revenue,

    -- Engagement metrics
    avg_playtime_minutes,
    median_playtime_minutes,
    peak_concurrent_users,

    -- Ratios
    ROUND(avg_playtime_minutes / NULLIF(price, 0), 2) AS playtime_per_dollar,
    ROUND(peak_concurrent_users / NULLIF(estimated_owners, 0) * 100, 4) AS ccu_conversion_rate,

    CURRENT_DATE() AS snapshot_date

FROM `workspace`.`raw_steam_staging`.`stg_steam_apps`
  