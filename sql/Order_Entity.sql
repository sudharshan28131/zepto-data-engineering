use role sysadmin;
use database sandbox;
use schema stage_sch;
use warehouse adhoc_wh;

create or replace table stage_sch.orders (
    orderid text comment 'Primary Key (Source System)',                  -- primary key is being stored as text
    customerid text comment 'Customer FK(Source System)',               -- foreign key reference is being stored as text (no constraint in snowflake)
    restaurantid text comment 'Restaurant FK(Source System)',             -- foreign key reference is being stored as text (no constraint in snowflake)
    orderdate text,                -- order date is being stored as text
    totalamount text,              -- total amount is being stored as text without decimal constraint
    status text,                   -- status is being stored as text
    paymentmethod text,            -- payment method is being stored as text
    createddate text,              -- created date is being stored as text
    modifieddate text,             -- modified date is being stored as text

    -- audit columns are being added with appropriate data types
    _stg_file_name text,
    _stg_file_load_ts timestamp,
    _stg_file_md5 text,
    _copy_data_ts timestamp default current_timestamp
)
comment = 'This order stage/raw table is being used to store data copied from the internal stage using the COPY command. The data is being represented as-is from the source location. All the columns are being stored as text data types except the audit columns, which are being added for traceability.';


create or replace stream stage_sch.orders_stm 
on table stage_sch.orders
append_only = true
comment = 'This append-only stream object is being created on the orders entity and is capturing only the delta data';


list  @stage_sch.csv_stg/delta/Orders/orders-initial.csv;


copy into stage_sch.orders (orderid, customerid, restaurantid, orderdate, totalamount, 
                  status, paymentmethod, createddate, modifieddate,
                  _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as orderid,
        t.$2::text as customerid,
        t.$3::text as restaurantid,
        t.$4::text as orderdate,
        t.$5::text as totalamount,
        t.$6::text as status,
        t.$7::text as paymentmethod,
        t.$8::text as createddate,
        t.$9::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/delta/Orders t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;


CREATE OR REPLACE TABLE CLEAN_SCH.ORDERS (
    ORDER_SK NUMBER AUTOINCREMENT PRIMARY KEY comment 'Surrogate Key (EDW)',                -- auto-incremented primary key is being generated
    ORDER_ID BIGINT UNIQUE comment 'Primary Key (Source System)',                      -- primary key is being stored as BIGINT
    CUSTOMER_ID_FK BIGINT comment 'Customer FK(Source System)',                   -- foreign key is being stored as BIGINT
    RESTAURANT_ID_FK BIGINT comment 'Restaurant FK(Source System)',                 -- foreign key is being stored as BIGINT
    ORDER_DATE TIMESTAMP,                 -- order date is being stored as TIMESTAMP
    TOTAL_AMOUNT DECIMAL(10, 2),          -- total amount is being stored as DECIMAL with two decimal places
    STATUS STRING,                        -- status is being stored as STRING
    PAYMENT_METHOD STRING,                -- payment method is being stored as STRING
    created_dt timestamp_tz,              -- record creation date is being stored
    modified_dt timestamp_tz,             -- last modified date is being stored and allowing NULL when not modified

    -- additional audit columns are being added
    _stg_file_name string,                -- file name is being stored for audit
    _stg_file_load_ts timestamp_ntz,      -- file load timestamp is being stored for audit
    _stg_file_md5 string,                 -- MD5 hash for file content is being stored for audit
    _copy_data_ts timestamp_ntz default current_timestamp -- timestamp of data copying is being recorded
)
comment = 'This order entity is being maintained under the clean schema with appropriate data types. Data is being populated using a MERGE statement from the stage layer. This table is not supporting SCD2';


-- Stream object is being created to capture the changes.
create or replace stream CLEAN_SCH.ORDERS_stm 
on table CLEAN_SCH.ORDERS
comment = 'This stream object is being created on the ORDERS table and is tracking insert, update, and delete changes';


MERGE INTO CLEAN_SCH.ORDERS AS target
USING STAGE_SCH.ORDERS_STM AS source
    ON target.ORDER_ID = TRY_TO_NUMBER(source.ORDERID) -- records are being matched based on ORDER_ID
WHEN MATCHED THEN
    -- existing records are being updated
    UPDATE SET
        TOTAL_AMOUNT = TRY_TO_DECIMAL(source.TOTALAMOUNT),
        STATUS = source.STATUS,
        PAYMENT_METHOD = source.PAYMENTMETHOD,
        MODIFIED_DT = TRY_TO_TIMESTAMP_TZ(source.MODIFIEDDATE),
        _STG_FILE_NAME = source._STG_FILE_NAME,
        _STG_FILE_LOAD_TS = source._STG_FILE_LOAD_TS,
        _STG_FILE_MD5 = source._STG_FILE_MD5,
        _COPY_DATA_TS = CURRENT_TIMESTAMP
WHEN NOT MATCHED THEN
    -- new records are being inserted
    INSERT (
        ORDER_ID,
        CUSTOMER_ID_FK,
        RESTAURANT_ID_FK,
        ORDER_DATE,
        TOTAL_AMOUNT,
        STATUS,
        PAYMENT_METHOD,
        CREATED_DT,
        MODIFIED_DT,
        _STG_FILE_NAME,
        _STG_FILE_LOAD_TS,
        _STG_FILE_MD5,
        _COPY_DATA_TS
    )
    VALUES (
        TRY_TO_NUMBER(source.ORDERID),
        TRY_TO_NUMBER(source.CUSTOMERID),
        TRY_TO_NUMBER(source.RESTAURANTID),
        TRY_TO_TIMESTAMP(source.ORDERDATE),
        TRY_TO_DECIMAL(source.TOTALAMOUNT),
        source.STATUS,
        source.PAYMENTMETHOD,
        TRY_TO_TIMESTAMP_TZ(source.CREATEDDATE),
        TRY_TO_TIMESTAMP_TZ(source.MODIFIEDDATE),
        source._STG_FILE_NAME,
        source._STG_FILE_LOAD_TS,
        source._STG_FILE_MD5,
        CURRENT_TIMESTAMP
    );


-- part-2
list @stage_sch.csv_stg/delta/Orders/;

copy into stage_sch.orders (orderid, customerid, restaurantid, orderdate, totalamount, 
                  status, paymentmethod, createddate, modifieddate,
                  _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as orderid,
        t.$2::text as customerid,
        t.$3::text as restaurantid,
        t.$4::text as orderdate,
        t.$5::text as totalamount,
        t.$6::text as status,
        t.$7::text as paymentmethod,
        t.$8::text as createddate,
        t.$9::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/initial/Orders t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;

select *
from stage_sch.orders_stm;
