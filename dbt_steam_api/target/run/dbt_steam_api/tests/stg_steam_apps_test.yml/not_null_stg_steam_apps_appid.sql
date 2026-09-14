
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select appid
from `workspace`.`raw_steam_staging`.`stg_steam_apps`
where appid is null



  
  
      
    ) dbt_internal_test