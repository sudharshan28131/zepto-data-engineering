use role sysadmin;
use warehouse adhoc_wh;
use database sandbox;
use schema consumption_sch;

select * from consumption_sch.order_item_fact limit 100;

create or replace view consumption_sch.vw_yearly_revenue_kpis as
select
    d.year as year, -- year is being fetched from date_dim
    sum(fact.subtotal) as total_revenue,
    count(distinct fact.order_id) as total_orders,
    round(sum(fact.subtotal) / count(distinct fact.order_id), 2) as avg_revenue_per_order,
    round(sum(fact.subtotal) / count(fact.order_item_id), 2) as avg_revenue_per_item,
    max(fact.subtotal) as max_order_value
from
    consumption_sch.order_item_fact fact
join
    consumption_sch.date_dim d
on
    fact.order_date_dim_key = d.date_dim_hk -- fact table is being joined with date_dim table
where DELIVERY_STATUS = 'Delivered'
group by
    d.year
order by
    d.year;

select *
from consumption_sch.vw_yearly_revenue_kpis;


CREATE OR REPLACE VIEW consumption_sch.vw_monthly_revenue_kpis AS
SELECT
    d.YEAR AS year,                       -- year is being fetched from DATE_DIM
    d.MONTH AS month,                     -- month is being fetched from DATE_DIM
    SUM(fact.subtotal) AS total_revenue,
    COUNT(DISTINCT fact.order_id) AS total_orders,
    ROUND(SUM(fact.subtotal) / COUNT(DISTINCT fact.order_id), 2) AS avg_revenue_per_order,
    ROUND(SUM(fact.subtotal) / COUNT(fact.order_item_id), 2) AS avg_revenue_per_item,
    MAX(fact.subtotal) AS max_order_value
FROM
    consumption_sch.order_item_fact fact
JOIN
    consumption_sch.DATE_DIM d
ON
    fact.order_date_dim_key = d.DATE_DIM_HK -- fact table is being joined with DATE_DIM table
where DELIVERY_STATUS = 'Delivered'
GROUP BY
    d.YEAR, d.MONTH
ORDER BY
    d.YEAR, d.MONTH;

select *
from consumption_sch.vw_monthly_revenue_kpis;


CREATE OR REPLACE VIEW consumption_sch.vw_daily_revenue_kpis AS
SELECT
    d.YEAR AS year,                       -- year is being fetched from DATE_DIM
    d.MONTH AS month,                     -- month is being fetched from DATE_DIM
    d.DAY_OF_THE_MONTH AS day,            -- day is being fetched from DATE_DIM
    SUM(fact.subtotal) AS total_revenue,
    COUNT(DISTINCT fact.order_id) AS total_orders,
    ROUND(SUM(fact.subtotal) / COUNT(DISTINCT fact.order_id), 2) AS avg_revenue_per_order,
    ROUND(SUM(fact.subtotal) / COUNT(fact.order_item_id), 2) AS avg_revenue_per_item,
    MAX(fact.subtotal) AS max_order_value
FROM
    consumption_sch.order_item_fact fact
JOIN
    consumption_sch.DATE_DIM d
ON
    fact.order_date_dim_key = d.DATE_DIM_HK -- fact table is being joined with DATE_DIM table
    where DELIVERY_STATUS = 'Delivered'
GROUP BY
    d.YEAR, d.MONTH, d.DAY_OF_THE_MONTH     -- data is being grouped by year, month, and day
ORDER BY
    d.YEAR, d.MONTH, d.DAY_OF_THE_MONTH;    -- data is being ordered by year, month, and day

 
select *
from consumption_sch.vw_daily_revenue_kpis;


CREATE OR REPLACE VIEW consumption_sch.vw_day_revenue_kpis AS
SELECT
    d.YEAR AS year,                       -- year is being fetched from DATE_DIM
    d.MONTH AS month,                     -- month is being fetched from DATE_DIM
    d.DAY_NAME AS DAY_NAME,               -- day name is being fetched from DATE_DIM
    SUM(fact.subtotal) AS total_revenue,
    COUNT(DISTINCT fact.order_id) AS total_orders,
    ROUND(SUM(fact.subtotal) / COUNT(DISTINCT fact.order_id), 2) AS avg_revenue_per_order,
    ROUND(SUM(fact.subtotal) / COUNT(fact.order_item_id), 2) AS avg_revenue_per_item,
    MAX(fact.subtotal) AS max_order_value
FROM
    consumption_sch.order_item_fact fact
JOIN
    consumption_sch.DATE_DIM d
ON
    fact.order_date_dim_key = d.DATE_DIM_HK -- fact table is being joined with DATE_DIM table
GROUP BY
    d.YEAR, d.MONTH, d.DAY_NAME     -- data is being grouped by year, month, and day
ORDER BY
    d.YEAR, d.MONTH, d.DAY_NAME;    -- data is being ordered by year, month, and day

select *
from consumption_sch.vw_day_revenue_kpis;


CREATE OR REPLACE VIEW consumption_sch.vw_monthly_revenue_by_restaurant AS
SELECT
    d.YEAR AS year,                       -- year is being fetched from DATE_DIM
    d.MONTH AS month,                     -- month is being fetched from DATE_DIM
    fact.DELIVERY_STATUS,
    r.name as restaurant_name,
    SUM(fact.subtotal) AS total_revenue,
    COUNT(DISTINCT fact.order_id) AS total_orders,
    ROUND(SUM(fact.subtotal) / COUNT(DISTINCT fact.order_id), 2) AS avg_revenue_per_order,
    ROUND(SUM(fact.subtotal) / COUNT(fact.order_item_id), 2) AS avg_revenue_per_item,
    MAX(fact.subtotal) AS max_order_value
FROM
    consumption_sch.order_item_fact fact
JOIN
    consumption_sch.DATE_DIM d
ON
    fact.order_date_dim_key = d.DATE_DIM_HK 
JOIN
    consumption_sch.restaurant_dim r
ON
    fact.restaurant_dim_key = r.RESTAURANT_HK 
GROUP BY
    d.YEAR, d.MONTH,fact.DELIVERY_STATUS,restaurant_name
ORDER BY
    d.YEAR, d.MONTH;

select *
from consumption_sch.vw_monthly_revenue_by_restaurant;

LIST @STAGE_SCH.CSV_STG/delta/orders/;
