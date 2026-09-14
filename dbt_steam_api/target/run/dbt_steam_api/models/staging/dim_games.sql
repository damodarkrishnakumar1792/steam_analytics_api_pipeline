
  
    
        create or replace table `workspace`.`raw_steam_staging`.`dim_games`
      
      
    using delta
  
      
      
      
      
      
      
      
      
      as
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
FROM `workspace`.`raw_steam_staging`.`stg_steam_apps`
  