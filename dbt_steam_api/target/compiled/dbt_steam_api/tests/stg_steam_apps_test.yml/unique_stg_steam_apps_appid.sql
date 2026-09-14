
    
    

select
    appid as unique_field,
    count(*) as n_records

from `workspace`.`raw_steam_staging`.`stg_steam_apps`
where appid is not null
group by appid
having count(*) > 1


