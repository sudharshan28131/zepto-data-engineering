use role sysadmin;
use warehouse adhoc_wh;
use database sandbox;
use schema consumption_sch;


CREATE OR REPLACE TABLE consumption_sch.order_item_fact (
    order_item_fact_sk NUMBER AUTOINCREMENT comment 'Surrogate Key (EDW)', -- surrogate key is being generated for the fact table
    order_item_id NUMBER  comment 'Order Item FK (Source System)',        -- natural key is being stored from the source data
    order_id NUMBER  comment 'Order FK (Source System)',                  -- order reference is being stored
    customer_dim_key NUMBER  comment 'Order FK (Source System)',          -- customer dimension reference is being stored
    customer_address_dim_key NUMBER,                                     -- customer address dimension reference is being stored
    restaurant_dim_key NUMBER,                                           -- restaurant dimension reference is being stored
    restaurant_location_dim_key NUMBER,                                  -- restaurant location dimension reference is being stored
    menu_dim_key NUMBER,                                                 -- menu dimension reference is being stored
    delivery_agent_dim_key NUMBER,                                       -- delivery agent dimension reference is being stored
    order_date_dim_key NUMBER,                                           -- date dimension reference is being stored
    quantity NUMBER,                                                     -- quantity is being stored as a measure
    price NUMBER(10, 2),                                                 -- price is being stored as a measure
    subtotal NUMBER(10, 2),                                              -- subtotal is being stored as a measure
    delivery_status VARCHAR,                                             -- delivery information is being stored
    estimated_time VARCHAR                                               -- estimated delivery time is being stored
)
comment = 'The order item fact table is being maintained with item-level price, quantity, and other details';


MERGE INTO consumption_sch.order_item_fact AS target
USING (
    SELECT 
        oi.Order_Item_ID AS order_item_id,
        oi.Order_ID_fk AS order_id,
        c.CUSTOMER_HK AS customer_dim_key,
        ca.CUSTOMER_ADDRESS_HK AS customer_address_dim_key,
        r.RESTAURANT_HK AS restaurant_dim_key, 
        rl.restaurant_location_hk as restaurant_location_dim_key,
        m.Menu_Dim_HK AS menu_dim_key,
        da.DELIVERY_AGENT_HK AS delivery_agent_dim_key,
        dd.DATE_DIM_HK AS order_date_dim_key,
        oi.Quantity::number(2) AS quantity,
        oi.Price AS price,
        oi.Subtotal AS subtotal,
        o.PAYMENT_METHOD,
        d.delivery_status AS delivery_status,
        d.estimated_time AS estimated_time,
    FROM 
        clean_sch.order_item_stm oi
    LEFT JOIN 
        clean_sch.orders_stm o ON oi.Order_ID_fk = o.Order_ID
    LEFT JOIN 
        clean_sch.delivery_stm d ON o.Order_ID = d.Order_ID_fk
    LEFT JOIN 
        consumption_sch.CUSTOMER_DIM c on o.Customer_ID_fk = c.customer_id
    LEFT JOIN 
        consumption_sch.CUSTOMER_ADDRESS_DIM ca on c.Customer_ID = ca.CUSTOMER_ID_fk
    LEFT JOIN 
        consumption_sch.restaurant_dim r on o.Restaurant_ID_fk = r.restaurant_id
    LEFT JOIN 
        consumption_sch.menu_dim m ON oi.MENU_ID_fk = m.menu_id
    LEFT JOIN 
        consumption_sch.delivery_agent_dim da ON d.Delivery_Agent_ID_fk = da.delivery_agent_id
    LEFT JOIN 
        consumption_sch.restaurant_location_dim rl on r.LOCATION_ID_FK = rl.location_id
    LEFT JOIN 
        CONSUMPTION_SCH.DATE_DIM dd on dd.calendar_date = date(o.order_date)
) AS source_stm
ON 
    target.order_item_id = source_stm.order_item_id and 
    target.order_id = source_stm.order_id
WHEN MATCHED THEN
    -- existing fact record is being updated
    UPDATE SET
        target.customer_dim_key = source_stm.customer_dim_key,
        target.customer_address_dim_key = source_stm.customer_address_dim_key,
        target.restaurant_dim_key = source_stm.restaurant_dim_key,
        target.restaurant_location_dim_key = source_stm.restaurant_location_dim_key,
        target.menu_dim_key = source_stm.menu_dim_key,
        target.delivery_agent_dim_key = source_stm.delivery_agent_dim_key,
        target.order_date_dim_key = source_stm.order_date_dim_key,
        target.quantity = source_stm.quantity,
        target.price = source_stm.price,
        target.subtotal = source_stm.subtotal,
        target.delivery_status = source_stm.delivery_status,
        target.estimated_time = source_stm.estimated_time
WHEN NOT MATCHED THEN
    -- new fact record is being inserted
    INSERT (
        order_item_id,
        order_id,
        customer_dim_key,
        customer_address_dim_key,
        restaurant_dim_key,
        restaurant_location_dim_key,
        menu_dim_key,
        delivery_agent_dim_key,
        order_date_dim_key,
        quantity,
        price,
        subtotal,
        delivery_status,
        estimated_time
    )
    VALUES (
        source_stm.order_item_id,
        source_stm.order_id,
        source_stm.customer_dim_key,
        source_stm.customer_address_dim_key,
        source_stm.restaurant_dim_key,
        source_stm.restaurant_location_dim_key,
        source_stm.menu_dim_key,
        source_stm.delivery_agent_dim_key,
        source_stm.order_date_dim_key,
        source_stm.quantity,
        source_stm.price,
        source_stm.subtotal,
        source_stm.delivery_status,
        source_stm.estimated_time
    );


-- foreign key relationships are being added to connect the fact table with the dimension tables
alter table consumption_sch.order_item_fact
    add constraint fk_order_item_fact_customer_dim
    foreign key (customer_dim_key)
    references consumption_sch.customer_dim (customer_hk);

alter table consumption_sch.order_item_fact
    add constraint fk_order_item_fact_customer_address_dim
    foreign key (customer_address_dim_key)
    references consumption_sch.customer_address_dim (CUSTOMER_ADDRESS_HK);

alter table consumption_sch.order_item_fact
    add constraint fk_order_item_fact_restaurant_dim
    foreign key (restaurant_dim_key)
    references consumption_sch.restaurant_dim (restaurant_hk);

alter table consumption_sch.order_item_fact
    add constraint fk_order_item_fact_restaurant_location_dim
    foreign key (restaurant_location_dim_key)
    references consumption_sch.restaurant_location_dim (restaurant_location_hk);

alter table consumption_sch.order_item_fact
    add constraint fk_order_item_fact_menu_dim
    foreign key (menu_dim_key)
    references consumption_sch.menu_dim (menu_dim_hk);

alter table consumption_sch.order_item_fact
    add constraint fk_order_item_fact_delivery_agent_dim
    foreign key (delivery_agent_dim_key)
    references consumption_sch.delivery_agent_dim (delivery_agent_hk);

alter table consumption_sch.order_item_fact
    add constraint fk_order_item_fact_delivery_date_dim
    foreign key (order_date_dim_key)
    references consumption_sch.date_dim (date_dim_hk);


-- stream data is being checked
select *
from clean_sch.order_item_stm;

-- stream data is being checked
SELECT *
FROM clean_sch.order_item_stm;

-- order stream data is being checked
SELECT * 
FROM clean_sch.orders_stm;

-- delivery stream data is being checked
SELECT *
FROM clean_sch.delivery_stm;

-- record counts are being checked in the clean tables
SELECT COUNT(*) FROM CLEAN_SCH.ORDER_ITEM;
SELECT COUNT(*) FROM CLEAN_SCH.ORDERS;
SELECT COUNT(*) FROM CLEAN_SCH.DELIVERY;


-- stream record counts are being checked
SELECT COUNT(*) FROM CLEAN_SCH.ORDER_ITEM_STM;

SELECT COUNT(*) FROM CLEAN_SCH.ORDERS_STM;

SELECT COUNT(*) FROM CLEAN_SCH.DELIVERY_STM;


-- matching order item and order records are being checked
SELECT
    oi.ORDER_ITEM_ID,
    oi.ORDER_ID_FK,
    o.ORDER_ID
FROM CLEAN_SCH.ORDER_ITEM_STM oi
JOIN CLEAN_SCH.ORDERS_STM o
    ON oi.ORDER_ID_FK = o.ORDER_ID;
