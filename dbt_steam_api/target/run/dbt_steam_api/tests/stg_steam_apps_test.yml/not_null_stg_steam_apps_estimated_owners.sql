
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select estimated_owners
from `workspace`.`raw_steam_staging`.`stg_steam_apps`
where estimated_owners is null



  
  
      
    ) dbt_internal_test