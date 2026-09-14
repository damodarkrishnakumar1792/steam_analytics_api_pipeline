
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    appid as unique_field,
    count(*) as n_records

from `workspace`.`raw_steam_staging`.`stg_steam_apps`
where appid is not null
group by appid
having count(*) > 1



  
  
      
    ) dbt_internal_test