use role sysadmin;

use database sandbox;
use schema stage_sch;
use warehouse adhoc_wh;

list @stage_sch.csv_stg/delta/Delivery/;

-- Adding the delivery table for storing the source delivery information
create or replace table stage_sch.delivery (
    deliveryid text comment 'Primary Key (Source System)', -- Storing the delivery ID as text
    orderid text comment 'Order FK (Source System)', -- Storing the order reference as text
    deliveryagentid text comment 'Delivery Agent FK(Source System)', -- Storing the delivery agent reference as text
    deliverystatus text, -- Storing the delivery status as text
    estimatedtime text, -- Storing the estimated delivery time as text
    addressid text comment 'Customer Address FK(Source System)', -- Storing the customer address reference as text
    deliverydate text, -- Storing the delivery date as text
    createddate text, -- Storing the creation date as text
    modifieddate text, -- Storing the modification date as text

    -- Adding audit columns for tracking file and loading details
    _stg_file_name text,
    _stg_file_load_ts timestamp,
    _stg_file_md5 text,
    _copy_data_ts timestamp default current_timestamp
)
comment = 'The delivery stage/raw table is being used for copying data from the internal stage using the copy command. The source data is being kept in its original representation. All columns are being stored as text except the audit columns that are being added for traceability.';


-- Creating a stream for capturing newly added delivery changes
create or replace stream stage_sch.delivery_stm 
on table stage_sch.delivery
append_only = true
comment = 'This append-only stream is being used on the delivery table for capturing only the newly added delta data';


-- Loading the initial delivery data from the internal stage into the stage table
copy into stage_sch.delivery (deliveryid,orderid, deliveryagentid, deliverystatus, 
                    estimatedtime, addressid, deliverydate, createddate, 
                    modifieddate, _stg_file_name, _stg_file_load_ts, 
                    _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as deliveryid,
        t.$2::text as orderid,
        t.$3::text as deliveryagentid,
        t.$4::text as deliverystatus,
        t.$5::text as estimatedtime,
        t.$6::text as addressid,
        t.$7::text as deliverydate,
        t.$8::text as createddate,
        t.$9::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/initial/Delivery/delivery-initial-load.csv t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;


-- Creating the delivery table in the clean layer with suitable data types
CREATE OR REPLACE TABLE clean_sch.delivery (
    delivery_sk INT AUTOINCREMENT PRIMARY KEY comment 'Surrogate Key (EDW)', -- Generating an auto-incrementing surrogate key
    delivery_id INT NOT NULL comment 'Primary Key (Source System)', -- Storing the delivery ID as an integer
    order_id_fk NUMBER NOT NULL comment 'Order FK (Source System)', -- Storing the order reference as a number
    delivery_agent_id_fk NUMBER NOT NULL comment 'Delivery Agent FK (Source System)', -- Storing the delivery agent reference as a number
    delivery_status STRING, -- Storing the delivery status as a string
    estimated_time STRING, -- Storing the estimated delivery time as a string
    customer_address_id_fk NUMBER NOT NULL comment 'Customer Address FK (Source System)', -- Storing the customer address reference as a number
    delivery_date TIMESTAMP, -- Storing the delivery date as a timestamp
    created_date TIMESTAMP, -- Storing the creation date as a timestamp
    modified_date TIMESTAMP, -- Storing the modification date as a timestamp

    -- Adding audit columns for tracking source and loading details
    _stg_file_name STRING, -- Storing the source file name
    _stg_file_load_ts TIMESTAMP, -- Storing the source file loading timestamp
    _stg_file_md5 STRING, -- Storing the source file MD5 hash
    _copy_data_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- Storing the data copying timestamp
)
comment = 'The delivery entity is being maintained under the clean schema with suitable data types. The data is being populated using a merge statement from the stage layer. This table is not supporting SCD2';


-- Creating a stream for capturing changes in the clean delivery table
create or replace stream CLEAN_SCH.delivery_stm 
on table CLEAN_SCH.delivery
comment = 'This stream is being used on the delivery table for tracking insert, update, and delete changes';


-- Merging delivery changes from the stage stream into the clean table
MERGE INTO 
    clean_sch.delivery AS target
USING 
    stage_sch.delivery_stm AS source
ON 
    target.delivery_id = TO_NUMBER(source.deliveryid) and
    target.order_id_fk = TO_NUMBER(source.orderid) and
    target.delivery_agent_id_fk = TO_NUMBER(source.deliveryagentid)

WHEN MATCHED THEN
    -- Updating the existing delivery record with the latest data
    UPDATE SET
        delivery_status = source.deliverystatus,
        estimated_time = source.estimatedtime,
        customer_address_id_fk = TO_NUMBER(source.addressid),
        delivery_date = TO_TIMESTAMP(source.deliverydate),
        created_date = TO_TIMESTAMP(source.createddate),
        modified_date = TO_TIMESTAMP(source.modifieddate),
        _stg_file_name = source._stg_file_name,
        _stg_file_load_ts = source._stg_file_load_ts,
        _stg_file_md5 = source._stg_file_md5,
        _copy_data_ts = source._copy_data_ts

WHEN NOT MATCHED THEN
    -- Inserting a new delivery record when no match is being found
    INSERT (
        delivery_id,
        order_id_fk,
        delivery_agent_id_fk,
        delivery_status,
        estimated_time,
        customer_address_id_fk,
        delivery_date,
        created_date,
        modified_date,
        _stg_file_name,
        _stg_file_load_ts,
        _stg_file_md5,
        _copy_data_ts
    )
    VALUES (
        TO_NUMBER(source.deliveryid),
        TO_NUMBER(source.orderid),
        TO_NUMBER(source.deliveryagentid),
        source.deliverystatus,
        source.estimatedtime,
        TO_NUMBER(source.addressid),
        TO_TIMESTAMP(source.deliverydate),
        TO_TIMESTAMP(source.createddate),
        TO_TIMESTAMP(source.modifieddate),
        source._stg_file_name,
        source._stg_file_load_ts,
        source._stg_file_md5,
        source._copy_data_ts
    );


-- Loading the delivery delta file into the stage table
copy into stage_sch.delivery (deliveryid,orderid, deliveryagentid, deliverystatus, 
                    estimatedtime, addressid, deliverydate, createddate, 
                    modifieddate, _stg_file_name, _stg_file_load_ts, 
                    _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as deliveryid,
        t.$2::text as orderid,
        t.$3::text as deliveryagentid,
        t.$4::text as deliverystatus,
        t.$5::text as estimatedtime,
        t.$6::text as addressid,
        t.$7::text as deliverydate,
        t.$8::text as createddate,
        t.$9::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/delta/Delivery/day-01-delivery.csv t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;


-- Checking the delivery stream for the changes that are currently being captured
select *
from stage_sch.delivery_stm;
