use role sysadmin;
use warehouse adhoc_wh;
use database sandbox;
use schema CONSUMPTION_SCH;


CREATE OR REPLACE TABLE CONSUMPTION_SCH.DATE_DIM (
    DATE_DIM_HK NUMBER PRIMARY KEY comment 'Menu Dim HK (EDW)',   -- surrogate key is being generated for the date dimension
    CALENDAR_DATE DATE UNIQUE,                                    -- actual calendar date is being stored
    YEAR NUMBER,                                                   -- year is being stored
    QUARTER NUMBER,                                                -- quarter is being stored (1-4)
    MONTH NUMBER,                                                  -- month is being stored (1-12)
    WEEK NUMBER,                                                   -- week of the year is being stored
    DAY_OF_YEAR NUMBER,                                            -- day of the year is being stored (1-365/366)
    DAY_OF_WEEK NUMBER,                                            -- day of the week is being stored (1-7)
    DAY_OF_THE_MONTH NUMBER,                                       -- day of the month is being stored (1-31)
    DAY_NAME STRING                                                -- name of the day is being stored (e.g., Monday)
)
comment = 'This date dimension table is being created using the minimum order date.';


insert into CONSUMPTION_SCH.DATE_DIM  
with recursive my_date_dim_cte as 
(
    -- anchor clause is being defined
    select 
        current_date() as today,
        year(today) as year,
        quarter(today) as quarter,
        month(today) as month,
        week(today) as week,
        dayofyear(today) as day_of_year,
        dayofweek(today) as day_of_week,
        day(today) as day_of_the_month,
        dayname(today) as day_name

    union all

    -- recursive clause is being defined
    select 
        dateadd('day', -1, today) as today_r,
        year(today_r) as year,
        quarter(today_r) as quarter,
        month(today_r) as month,
        week(today_r) as week,
        dayofyear(today_r) as day_of_year,
        dayofweek(today_r) as day_of_week,
        day(today_r) as day_of_the_month,
        dayname(today_r) as day_name
    from 
        my_date_dim_cte
    where 
        today_r > (select date(min(order_date)) from clean_sch.orders)
)
select 
    hash(SHA1_hex(today)) as DATE_DIM_HK,
    today ,                     -- actual calendar date is being stored
    YEAR,                       -- year is being stored
    QUARTER,                    -- quarter is being stored (1-4)
    MONTH,                      -- month is being stored (1-12)
    WEEK,                       -- week of the year is being stored
    DAY_OF_YEAR,                -- day of the year is being stored (1-365/366)
    DAY_OF_WEEK,                -- day of the week is being stored (1-7)
    DAY_OF_THE_MONTH,            -- day of the month is being stored (1-31)
    DAY_NAME                    -- day name is being stored
from my_date_dim_cte;

select *
from CONSUMPTION_SCH.DATE_DIM;
