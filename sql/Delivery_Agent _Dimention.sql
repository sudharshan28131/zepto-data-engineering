use role sysadmin;
use database sandbox;
use schema stage_sch;
use warehouse adhoc_wh;

create or replace table stage_sch.deliveryagent (
    deliveryagentid text comment 'Primary Key (Source System)',         -- Storing the primary key as text
    name text,           -- Storing the delivery agent name as text
    phone text,            -- Storing the phone number as text
    vehicletype text,             -- Storing the vehicle type as text
    locationid text,              -- Storing the location reference as text
    status text,                  -- Storing the delivery agent status as text
    gender text,                  -- Storing the gender information as text
    rating text,                  -- Storing the rating as text
    createddate text,             -- Storing the creation date as text
    modifieddate text,            -- Storing the modification date as text

    -- Adding audit columns for tracking file and loading details
    _stg_file_name text,
    _stg_file_load_ts timestamp,
    _stg_file_md5 text,
    _copy_data_ts timestamp default current_timestamp
)
comment = 'This is the delivery stage/raw table where data is being copied from the internal stage using the copy command. This is keeping the data in the same format as the source. All the columns are being stored as text except the audit columns that are being added for traceability.';


create or replace stream stage_sch.deliveryagent_stm 
on table stage_sch.deliveryagent
append_only = true
comment = 'This is the append-only stream object on the delivery agent table that is capturing only the newly added delta data';


copy into stage_sch.deliveryagent (deliveryagentid, name, phone, vehicletype, locationid, 
                          status, gender, rating, createddate, modifieddate,
                          _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as deliveryagentid,
        t.$2::text as name,
        t.$3::text as phone,
        t.$4::text as vehicletype,
        t.$5::text as locationid,
        t.$6::text as status,
        t.$7::text as gender,
        t.$8::text as rating,
        t.$9::text as createddate,
        t.$10::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/initial/Delivery-Agent t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;


select count(*) from stage_sch.deliveryagent;

select * from stage_sch.deliveryagent_stm;


CREATE OR REPLACE TABLE clean_sch.delivery_agent (
    delivery_agent_sk INT AUTOINCREMENT PRIMARY KEY comment 'Surrogate Key (EDW)', -- Generating an auto-incrementing surrogate key
    delivery_agent_id INT NOT NULL UNIQUE comment 'Primary Key (Source System)', -- Storing the delivery agent ID as an integer
    name STRING NOT NULL,                -- Storing the delivery agent name
    phone STRING NOT NULL,               -- Storing the phone number
    vehicle_type STRING NOT NULL,        -- Storing the vehicle type
    location_id_fk INT comment 'Location FK(Source System)', -- Storing the location ID as an integer
    status STRING,                       -- Storing the delivery agent status
    gender STRING,                       -- Storing the gender information
    rating number(4,2),                  -- Storing the rating with decimal precision
    created_dt TIMESTAMP_NTZ,            -- Storing the creation date as a timestamp
    modified_dt TIMESTAMP_NTZ,            -- Storing the modification date as a timestamp

    -- Adding audit columns for tracking file and loading details
    _stg_file_name STRING,               -- Storing the staging file name
    _stg_file_load_ts TIMESTAMP,         -- Storing the staging file loading timestamp
    _stg_file_md5 STRING,                -- Storing the staging file MD5 hash
    _copy_data_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- Storing the data copying timestamp
)
comment = 'The delivery agent entity is being maintained under the clean schema with suitable data types. The data is being populated using the merge statement from the stage layer. This table is not supporting SCD2';


create or replace stream CLEAN_SCH.delivery_agent_stm 
on table CLEAN_SCH.delivery_agent
comment = 'This stream object is being used on the delivery agent table for tracking insert, update, and delete changes';


MERGE INTO clean_sch.delivery_agent AS target
USING stage_sch.deliveryagent_stm AS source
ON target.delivery_agent_id = source.deliveryagentid

WHEN MATCHED THEN
    UPDATE SET
        target.phone = source.phone,
        target.vehicle_type = source.vehicletype,
        target.location_id_fk = TRY_TO_NUMBER(source.locationid),
        target.status = source.status,
        target.gender = source.gender,
        target.rating = TRY_TO_DECIMAL(source.rating,4,2),
        target.created_dt = TRY_TO_TIMESTAMP(source.createddate),
        target.modified_dt = TRY_TO_TIMESTAMP(source.modifieddate),
        target._stg_file_name = source._stg_file_name,
        target._stg_file_load_ts = source._stg_file_load_ts,
        target._stg_file_md5 = source._stg_file_md5,
        target._copy_data_ts = source._copy_data_ts

WHEN NOT MATCHED THEN
    INSERT (
        delivery_agent_id,
        name,
        phone,
        vehicle_type,
        location_id_fk,
        status,
        gender,
        rating,
        created_dt,
        modified_dt,
        _stg_file_name,
        _stg_file_load_ts,
        _stg_file_md5,
        _copy_data_ts
    )
    VALUES (
        TRY_TO_NUMBER(source.deliveryagentid),
        source.name,
        source.phone,
        source.vehicletype,
        TRY_TO_NUMBER(source.locationid),
        source.status,
        source.gender,
        TRY_TO_NUMBER(source.rating),
        TRY_TO_TIMESTAMP(source.createddate),
        TRY_TO_TIMESTAMP(source.modifieddate),
        source._stg_file_name,
        source._stg_file_load_ts,
        source._stg_file_md5,
        CURRENT_TIMESTAMP()
    );


select * from CLEAN_SCH.delivery_agent_stm;


CREATE OR REPLACE TABLE consumption_sch.delivery_agent_dim (
    delivery_agent_hk number primary key comment 'Delivery Agend Dim HK (EDW)', -- Generating a hash key for unique identification
    delivery_agent_id NUMBER not null comment 'Primary Key (Source System)', -- Storing the source system business key
    name STRING NOT NULL,                   -- Storing the delivery agent name
    phone STRING UNIQUE,                    -- Storing the phone number
    vehicle_type STRING,                    -- Storing the vehicle type
    location_id_fk NUMBER NOT NULL comment 'Location FK (Source System)', -- Storing the location ID
    status STRING,                          -- Storing the current delivery agent status
    gender STRING,                          -- Storing the gender information
    rating NUMBER(4,2),                     -- Storing the delivery agent rating
    eff_start_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Recording when the record is becoming active
    eff_end_date TIMESTAMP,                 -- Recording when the record is becoming inactive
    is_current BOOLEAN DEFAULT TRUE
)
comment = 'The delivery agent dimension is being maintained with SCD2 support for tracking historical changes.';


MERGE INTO consumption_sch.delivery_agent_dim AS target
USING CLEAN_SCH.delivery_agent_stm AS source
ON 
    target.delivery_agent_id = source.delivery_agent_id AND
    target.name = source.name AND
    target.phone = source.phone AND
    target.vehicle_type = source.vehicle_type AND
    target.location_id_fk = source.location_id_fk AND
    target.status = source.status AND
    target.gender = source.gender AND
    target.rating = source.rating

WHEN MATCHED 
    AND source.METADATA$ACTION = 'DELETE' 
    AND source.METADATA$ISUPDATE = 'TRUE' THEN

    -- Updating the existing record and closing its validity period
    UPDATE SET 
        target.eff_end_date = CURRENT_TIMESTAMP,
        target.is_current = FALSE

WHEN NOT MATCHED 
    AND source.METADATA$ACTION = 'INSERT' 
    AND source.METADATA$ISUPDATE = 'TRUE' THEN

    -- Inserting the updated record with a new effective start date
    INSERT (
        delivery_agent_hk,
        delivery_agent_id,
        name,
        phone,
        vehicle_type,
        location_id_fk,
        status,
        gender,
        rating,
        eff_start_date,
        eff_end_date,
        is_current
    )
    VALUES (
        hash(SHA1_HEX(CONCAT(source.delivery_agent_id, source.name, source.phone, 
            source.vehicle_type, source.location_id_fk, source.status, 
            source.gender, source.rating))), -- Generating the hash key

        delivery_agent_id,
        source.name,
        source.phone,
        source.vehicle_type,
        location_id_fk,
        source.status,
        source.gender,
        source.rating,

        CURRENT_TIMESTAMP,       -- Setting the effective start date
        NULL,                    -- Keeping the effective end date as NULL for the current record
        TRUE                     -- Marking the new record as current
    )

WHEN NOT MATCHED 
    AND source.METADATA$ACTION = 'INSERT' 
    AND source.METADATA$ISUPDATE = 'FALSE' THEN

    -- Inserting a new record with its effective start date
    INSERT (
        delivery_agent_hk,
        delivery_agent_id,
        name,
        phone,
        vehicle_type,
        location_id_fk,
        status,
        gender,
        rating,
        eff_start_date,
        eff_end_date,
        is_current
    )
    VALUES (
        hash(SHA1_HEX(CONCAT(source.delivery_agent_id, source.name, source.phone, 
            source.vehicle_type, source.location_id_fk, source.status,
            source.gender, source.rating))), -- Generating the hash key

        source.delivery_agent_id,
        source.name,
        source.phone,
        source.vehicle_type,
        source.location_id_fk,
        source.status,
        source.gender,
        source.rating,

        CURRENT_TIMESTAMP,       -- Setting the effective start date
        NULL,                    -- Keeping the effective end date as NULL for the current record
        TRUE                     -- Marking the new record as current
    );


-- part-2

copy into deliveryagent (deliveryagentid, name, phone, vehicletype, locationid, 
                          status, gender, rating, createddate, modifieddate,
                          _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as deliveryagentid,
        t.$2::text as name,
        t.$3::text as phone,
        t.$4::text as vehicletype,
        t.$5::text as locationid,
        t.$6::text as status,
        t.$7::text as gender,
        t.$8::text as rating,
        t.$9::text as createddate,
        t.$10::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/delta/Delivery-agent/day-02-delivery-agent.csv t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;
