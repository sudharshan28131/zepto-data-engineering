use role sysadmin;
use database sandbox;
use schema stage_sch;
use warehouse adhoc_wh;


-- Creating the customer address table in the stage layer and storing the source data as text
create or replace table stage_sch.customeraddress (
    addressid text,                    -- Storing address ID as text
    customerid text comment 'Customer FK (Source Data)',                   -- Storing the customer reference ID as text
    flatno text,                       -- Storing flat number as text
    houseno text,                      -- Storing house number as text
    floor text,                        -- Storing floor number as text
    building text,                     -- Storing building name as text
    landmark text,                     -- Storing nearby landmark as text
    locality text,                     -- Storing locality as text
    city text,                          -- Storing city as text
    state text,                         -- Storing state as text
    pincode text,                       -- Storing pincode as text
    coordinates text,                  -- Storing location coordinates as text
    primaryflag text,                  -- Storing the primary address flag as text
    addresstype text,                  -- Storing the type of address as text
    createddate text,                  -- Storing the creation date as text
    modifieddate text,                 -- Storing the modification date as text

    -- Adding audit columns for tracking file and data loading details
    _stg_file_name text,
    _stg_file_load_ts timestamp,
    _stg_file_md5 text,
    _copy_data_ts timestamp default current_timestamp
)
comment = 'This customer address table is being used as the stage/raw layer, where the source data is being copied from the internal stage. The data is being kept as-is, while audit columns are being added for tracking the file and loading details.';


-- Creating a stream for capturing newly loaded customer address changes
create or replace stream stage_sch.customeraddress_stm 
on table stage_sch.customeraddress
append_only = true
comment = 'This append-only stream is being used for capturing the newly added customer address records from the stage table';


-- Checking the customer address records that are currently being captured by the stream
select * 
from stage_sch.customeraddress_stm;


-- Loading the customer address data from the internal stage into the stage table
copy into stage_sch.customeraddress (addressid, customerid, flatno, houseno, floor, building, 
                               landmark, locality,city,pincode, state, coordinates, primaryflag, addresstype, 
                               createddate, modifieddate, 
                               _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as addressid,
        t.$2::text as customerid,
        t.$3::text as flatno,
        t.$4::text as houseno,
        t.$5::text as floor,
        t.$6::text as building,
        t.$7::text as landmark,
        t.$8::text as locality,
        t.$9::text as city,
        t.$10::text as State,
        t.$11::text as Pincode,
        t.$12::text as coordinates,
        t.$13::text as primaryflag,
        t.$14::text as addresstype,
        t.$15::text as createddate,
        t.$16::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/initial/Customer-Address t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;


-- ==========================================================
-- 2nd Layer: Clean Layer
-- ==========================================================

-- Creating the customer address table in the clean layer and converting the required values into suitable data types
CREATE OR REPLACE TABLE CLEAN_SCH.CUSTOMER_ADDRESS (
    CUSTOMER_ADDRESS_SK NUMBER AUTOINCREMENT PRIMARY KEY comment 'Surrogate Key (EWH)',                -- Generating an auto-incrementing key for the address
    ADDRESS_ID INT comment 'Primary Key (Source Data)',                 -- Storing the original address ID
    CUSTOMER_ID_FK INT comment 'Customer FK (Source Data)',                -- Storing the customer reference ID
    FLAT_NO STRING,                    -- Storing flat number as a string
    HOUSE_NO STRING,                   -- Storing house number as a string
    FLOOR STRING,                      -- Storing floor number as a string
    BUILDING STRING,                   -- Storing building name as a string
    LANDMARK STRING,                   -- Storing landmark as a string
    locality STRING,                   -- Storing locality as a string
    CITY STRING,                       -- Storing city as a string
    STATE STRING,                      -- Storing state as a string
    PINCODE STRING,                    -- Storing pincode as a string
    COORDINATES STRING,                -- Storing coordinates as a string
    PRIMARY_FLAG STRING,               -- Storing the primary address flag as a string
    ADDRESS_TYPE STRING,               -- Storing the address type as a string
    CREATED_DATE TIMESTAMP_TZ,         -- Storing the creation date as a timestamp
    MODIFIED_DATE TIMESTAMP_TZ,        -- Storing the modification date as a timestamp

    -- Adding audit columns for keeping track of the source file and loading information
    _STG_FILE_NAME STRING,
    _STG_FILE_LOAD_TS TIMESTAMP,
    _STG_FILE_MD5 STRING,
    _COPY_DATA_TS TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
comment = 'This customer address table is being used in the clean layer, where the raw address data is being converted into suitable data types. The data is being populated from the stage layer, and the table is being maintained without SCD Type 2 history.';


-- Creating a stream for capturing changes happening in the clean customer address table
create or replace stream CLEAN_SCH.CUSTOMER_ADDRESS_STM
on table CLEAN_SCH.CUSTOMER_ADDRESS
comment = 'This stream is being used for capturing insert, update, and delete changes happening in the clean customer address table';


-- Merging the customer address changes from the stage stream into the clean table
MERGE INTO clean_sch.customer_address AS clean
USING (
    SELECT 
        CAST(addressid AS INT) AS address_id,
        CAST(customerid AS INT) AS customer_id_fk,
        flatno AS flat_no,
        houseno AS house_no,
        floor,
        building,
        landmark,
        locality,
        city,
        state,
        pincode,
        coordinates,
        primaryflag AS primary_flag,
        addresstype AS address_type,
        TRY_TO_TIMESTAMP_TZ(createddate, 'YYYY-MM-DD"T"HH24:MI:SS') AS created_date,
        TRY_TO_TIMESTAMP_TZ(modifieddate, 'YYYY-MM-DD"T"HH24:MI:SS') AS modified_date,
        _stg_file_name,
        _stg_file_load_ts,
        _stg_file_md5,
        _copy_data_ts
    FROM stage_sch.customeraddress_stm 
) AS stage
ON clean.address_id = stage.address_id

-- Inserting the customer address when a new address is being found
WHEN NOT MATCHED THEN
    INSERT (
        address_id,
        customer_id_fk,
        flat_no,
        house_no,
        floor,
        building,
        landmark,
        locality,
        city,
        state,
        pincode,
        coordinates,
        primary_flag,
        address_type,
        created_date,
        modified_date,
        _stg_file_name,
        _stg_file_load_ts,
        _stg_file_md5,
        _copy_data_ts
    )
    VALUES (
        stage.address_id,
        stage.customer_id_fk,
        stage.flat_no,
        stage.house_no,
        stage.floor,
        stage.building,
        stage.landmark,
        stage.locality,
        stage.city,
        stage.state,
        stage.pincode,
        stage.coordinates,
        stage.primary_flag,
        stage.address_type,
        stage.created_date,
        stage.modified_date,
        stage._stg_file_name,
        stage._stg_file_load_ts,
        stage._stg_file_md5,
        stage._copy_data_ts
    )

-- Updating the existing customer address when changes are being detected
WHEN MATCHED THEN
    UPDATE SET
        clean.flat_no = stage.flat_no,
        clean.house_no = stage.house_no,
        clean.floor = stage.floor,
        clean.building = stage.building,
        clean.landmark = stage.landmark,
        clean.locality = stage.locality,
        clean.city = stage.city,
        clean.state = stage.state,
        clean.pincode = stage.pincode,
        clean.coordinates = stage.coordinates,
        clean.primary_flag = stage.primary_flag,
        clean.address_type = stage.address_type,
        clean.created_date = stage.created_date,
        clean.modified_date = stage.modified_date,
        clean._stg_file_name = stage._stg_file_name,
        clean._stg_file_load_ts = stage._stg_file_load_ts,
        clean._stg_file_md5 = stage._stg_file_md5,
        clean._copy_data_ts = stage._copy_data_ts;


-- Creating the customer address dimension for maintaining address history using SCD Type 2
CREATE OR REPLACE TABLE CONSUMPTION_SCH.CUSTOMER_ADDRESS_DIM (
    CUSTOMER_ADDRESS_HK NUMBER PRIMARY KEY comment 'Customer Address HK (EDW)',        -- Generating a hash key for the customer address
    ADDRESS_ID INT comment 'Primary Key (Source System)',                                -- Storing the original address ID
    CUSTOMER_ID_FK STRING comment 'Customer FK (Source System)',                            -- Storing the customer reference ID
    FLAT_NO STRING,                                -- Storing flat number
    HOUSE_NO STRING,                               -- Storing house number
    FLOOR STRING,                                  -- Storing floor number
    BUILDING STRING,                               -- Storing building name
    LANDMARK STRING,                               -- Storing landmark
    LOCALITY STRING,                               -- Storing locality
    CITY STRING,                                   -- Storing city
    STATE STRING,                                  -- Storing state
    PINCODE STRING,                                -- Storing pincode
    COORDINATES STRING,                            -- Storing geographical coordinates
    PRIMARY_FLAG STRING,                           -- Storing whether the address is primary
    ADDRESS_TYPE STRING,                           -- Storing the type of address

    -- Adding SCD Type 2 columns for tracking address history
    EFF_START_DATE TIMESTAMP_TZ,                  -- Recording when the address version is becoming active
    EFF_END_DATE TIMESTAMP_TZ,                    -- Recording when the address version is becoming inactive
    IS_CURRENT BOOLEAN                            -- Indicating whether the address record is currently active
);


-- Merging the address changes from the clean stream into the customer address dimension
MERGE INTO 
    CONSUMPTION_SCH.CUSTOMER_ADDRESS_DIM AS target
USING 
    CLEAN_SCH.CUSTOMER_ADDRESS_STM AS source
ON 
    target.ADDRESS_ID = source.ADDRESS_ID AND
    target.CUSTOMER_ID_FK = source.CUSTOMER_ID_FK AND
    target.FLAT_NO = source.FLAT_NO AND
    target.HOUSE_NO = source.HOUSE_NO AND
    target.FLOOR = source.FLOOR AND
    target.BUILDING = source.BUILDING AND
    target.LANDMARK = source.LANDMARK AND
    target.LOCALITY = source.LOCALITY AND
    target.CITY = source.CITY AND
    target.STATE = source.STATE AND
    target.PINCODE = source.PINCODE AND
    target.COORDINATES = source.COORDINATES AND
    target.PRIMARY_FLAG = source.PRIMARY_FLAG AND
    target.ADDRESS_TYPE = source.ADDRESS_TYPE

WHEN MATCHED 
    AND source.METADATA$ACTION = 'DELETE' AND source.METADATA$ISUPDATE = 'TRUE' THEN

    -- Closing the validity period when the existing address is being updated
    UPDATE SET 
        target.EFF_END_DATE = CURRENT_TIMESTAMP(),
        target.IS_CURRENT = FALSE

WHEN NOT MATCHED 
    AND source.METADATA$ACTION = 'INSERT' AND source.METADATA$ISUPDATE = 'TRUE' THEN

    -- Inserting the updated address version and starting a new validity period
    INSERT (
        CUSTOMER_ADDRESS_HK,
        ADDRESS_ID,
        CUSTOMER_ID_FK,
        FLAT_NO,
        HOUSE_NO,
        FLOOR,
        BUILDING,
        LANDMARK,
        LOCALITY,
        CITY,
        STATE,
        PINCODE,
        COORDINATES,
        PRIMARY_FLAG,
        ADDRESS_TYPE,
        EFF_START_DATE,
        EFF_END_DATE,
        IS_CURRENT
    )
    VALUES (
        hash(SHA1_hex(CONCAT(source.ADDRESS_ID, source.CUSTOMER_ID_FK, source.FLAT_NO, 
            source.HOUSE_NO, source.FLOOR, source.BUILDING, source.LANDMARK, 
            source.LOCALITY, source.CITY, source.STATE, source.PINCODE, 
            source.COORDINATES, source.PRIMARY_FLAG, source.ADDRESS_TYPE))),
        source.ADDRESS_ID,
        source.CUSTOMER_ID_FK,
        source.FLAT_NO,
        source.HOUSE_NO,
        source.FLOOR,
        source.BUILDING,
        source.LANDMARK,
        source.LOCALITY,
        source.CITY,
        source.STATE,
        source.PINCODE,
        source.COORDINATES,
        source.PRIMARY_FLAG,
        source.ADDRESS_TYPE,
        CURRENT_TIMESTAMP(),
        NULL,
        TRUE
    )

WHEN NOT MATCHED 
    AND source.METADATA$ACTION = 'INSERT' AND source.METADATA$ISUPDATE = 'FALSE' THEN

    -- Inserting a new address record and starting its validity period
    INSERT (
        CUSTOMER_ADDRESS_HK,
        ADDRESS_ID,
        CUSTOMER_ID_FK,
        FLAT_NO,
        HOUSE_NO,
        FLOOR,
        BUILDING,
        LANDMARK,
        LOCALITY,
        CITY,
        STATE,
        PINCODE,
        COORDINATES,
        PRIMARY_FLAG,
        ADDRESS_TYPE,
        EFF_START_DATE,
        EFF_END_DATE,
        IS_CURRENT
    )
    VALUES (
        hash(SHA1_hex(CONCAT(source.ADDRESS_ID, source.CUSTOMER_ID_FK, source.FLAT_NO, 
            source.HOUSE_NO, source.FLOOR, source.BUILDING, source.LANDMARK, 
            source.LOCALITY, source.CITY, source.STATE, source.PINCODE, 
            source.COORDINATES, source.PRIMARY_FLAG, source.ADDRESS_TYPE))),
        source.ADDRESS_ID,
        source.CUSTOMER_ID_FK,
        source.FLAT_NO,
        source.HOUSE_NO,
        source.FLOOR,
        source.BUILDING,
        source.LANDMARK,
        source.LOCALITY,
        source.CITY,
        source.STATE,
        source.PINCODE,
        source.COORDINATES,
        source.PRIMARY_FLAG,
        source.ADDRESS_TYPE,
        CURRENT_TIMESTAMP(),
        NULL,
        TRUE
    );


-- Checking the customer address records across the different layers
select * from stage_sch.customeraddress;
select * from CLEAN_SCH.CUSTOMER_ADDRESS;
select * from CONSUMPTION_SCH.CUSTOMER_ADDRESS_DIM;


-- Checking the available customer address delta files before loading new changes
list @stage_sch.csv_stg/delta/Customer_address;


-- Loading the new customer address delta file into the stage table
copy into stage_sch.customeraddress (addressid, customerid, flatno, houseno, floor, building, 
                               landmark, locality,city,pincode, state, coordinates, primaryflag, addresstype, 
                               createddate, modifieddate, 
                               _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as addressid,
        t.$2::text as customerid,
        t.$3::text as flatno,
        t.$4::text as houseno,
        t.$5::text as floor,
        t.$6::text as building,
        t.$7::text as landmark,
        t.$8::text as locality,
        t.$9::text as city,
        t.$10::text as State,
        t.$11::text as Pincode,
        t.$12::text as coordinates,
        t.$13::text as primaryflag,
        t.$14::text as addresstype,
        t.$15::text as createddate,
        t.$16::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/delta/Customer_address/day-02-customer-address-book.csv t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;
