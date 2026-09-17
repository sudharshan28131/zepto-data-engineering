use role sysadmin;
use database sandbox;
use schema stage_sch;
use warehouse adhoc_wh;

create or replace table stage_sch.orderitem (
    orderitemid text comment 'Primary Key (Source System)',              -- primary key is being stored as text
    orderid text comment 'Order FK(Source System)',                      -- foreign key reference is being stored as text (no constraint in snowflake)
    menuid text comment 'Menu FK(Source System)',                        -- foreign key reference is being stored as text (no constraint in snowflake)
    quantity text,                                                       -- quantity is being stored as text
    price text,                                                          -- price is being stored as text
    subtotal text,                                                       -- subtotal is being stored as text
    createddate text,                                                    -- created date is being stored as text
    modifieddate text,                                                   -- modified date is being stored as text

    -- audit columns are being added with appropriate data types
    _stg_file_name text,
    _stg_file_load_ts timestamp,
    _stg_file_md5 text,
    _copy_data_ts timestamp default current_timestamp
)
comment = 'This order item stage/raw table is being used to store data copied from the internal stage using the COPY command. The data is being represented as-is from the source location. All columns are being stored as text data types except the audit columns, which are being added for traceability.';


create or replace stream stage_sch.orderitem_stm 
on table stage_sch.orderitem
append_only = true
comment = 'This append-only stream object is being created on the order item table and is capturing only the delta data';


list @stage_sch.csv_stg/initial/Order_item;

copy into stage_sch.orderitem (orderitemid, orderid, menuid, quantity, price, 
                     subtotal, createddate, modifieddate,
                     _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as orderitemid,
        t.$2::text as orderid,
        t.$3::text as menuid,
        t.$4::text as quantity,
        t.$5::text as price,
        t.$6::text as subtotal,
        t.$7::text as createddate,
        t.$8::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/delta/Order__items t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;

select * from stage_sch.orderitem;
select * from stage_sch.orderitem_stm;


CREATE OR REPLACE TABLE clean_sch.order_item (
    order_item_sk NUMBER AUTOINCREMENT primary key comment 'Surrogate Key (EDW)',    -- auto-incremented unique identifier is being generated for each order item
    order_item_id NUMBER  NOT NULL UNIQUE comment 'Primary Key (Source System)',
    order_id_fk NUMBER  NOT NULL comment 'Order FK(Source System)',                  -- foreign key reference is being stored for Order ID
    menu_id_fk NUMBER  NOT NULL comment 'Menu FK(Source System)',                   -- foreign key reference is being stored for Menu ID
    quantity NUMBER(10, 2),                                                          -- quantity is being stored as a decimal number
    price NUMBER(10, 2),                                                             -- price is being stored as a decimal number
    subtotal NUMBER(10, 2),                                                          -- subtotal is being stored as a decimal number
    created_dt TIMESTAMP,                                                            -- created date is being stored for the order item
    modified_dt TIMESTAMP,                                                           -- modified date is being stored for the order item

    -- audit columns are being added
    _stg_file_name VARCHAR(255),                                                     -- staging file name is being stored
    _stg_file_load_ts TIMESTAMP,                                                     -- file load timestamp is being stored
    _stg_file_md5 VARCHAR(255),                                                      -- MD5 hash of the file is being stored for integrity checking
    _copy_data_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP                                -- timestamp of data copying is being recorded in the clean layer
)
comment = 'This order item entity is being maintained under the clean schema with appropriate data types. Data is being populated using a MERGE statement from the stage layer. This table is not supporting SCD2';


create or replace stream CLEAN_SCH.order_item_stm 
on table CLEAN_SCH.order_item
comment = 'This stream object is being created on the order_item table and is tracking insert, update, and delete changes';


select * from clean_sch.order_item_stm;


MERGE INTO clean_sch.order_item AS target
USING stage_sch.orderitem_stm AS source
ON  
    target.order_item_id = source.orderitemid and
    target.order_id_fk = source.orderid and
    target.menu_id_fk = source.menuid
WHEN MATCHED THEN
    -- existing record is being updated with new data
    UPDATE SET 
        target.quantity = source.quantity,
        target.price = source.price,
        target.subtotal = source.subtotal,
        target.created_dt = source.createddate,
        target.modified_dt = source.modifieddate,
        target._stg_file_name = source._stg_file_name,
        target._stg_file_load_ts = source._stg_file_load_ts,
        target._stg_file_md5 = source._stg_file_md5,
        target._copy_data_ts = source._copy_data_ts
WHEN NOT MATCHED THEN
    -- new record is being inserted when no match is being found
    INSERT (
        order_item_id,
        order_id_fk,
        menu_id_fk,
        quantity,
        price,
        subtotal,
        created_dt,
        modified_dt,
        _stg_file_name,
        _stg_file_load_ts,
        _stg_file_md5,
        _copy_data_ts
    )
    VALUES (
        source.orderitemid,
        source.orderid,
        source.menuid,
        source.quantity,
        source.price,
        source.subtotal,
        source.createddate,
        source.modifieddate,
        source._stg_file_name,
        source._stg_file_load_ts,
        source._stg_file_md5,
        CURRENT_TIMESTAMP()
    );


-- part-2
list @stage_sch.csv_stg/delta/Order__items/;

copy into stage_sch.orderitem (orderitemid, orderid, menuid, quantity, price, 
                     subtotal, createddate, modifieddate,
                     _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as orderitemid,
        t.$2::text as orderid,
        t.$3::text as menuid,
        t.$4::text as quantity,
        t.$5::text as price,
        t.$6::text as subtotal,
        t.$7::text as createddate,
        t.$8::text as createddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/delta/Order__items t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;
