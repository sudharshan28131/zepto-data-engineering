use role sysadmin;
use database sandbox;
use schema stage_sch;
use warehouse adhoc_wh;

-- Creating the customer table in the stage layer and keeping the source values as text
create or replace table stage_sch.customer (
    customerid text,                    -- Storing customer ID as text
    name text,                          -- Storing customer name as text
    mobile text WITH TAG (common.pii_policy_tag = 'PII'),                        -- Storing mobile number as text
    email text WITH TAG (common.pii_policy_tag = 'EMAIL'),                         -- Storing email as text
    loginbyusing text,                  -- Storing the login method as text
    gender text WITH TAG (common.pii_policy_tag = 'PII'),                        -- Storing gender as text
    dob text WITH TAG (common.pii_policy_tag = 'PII'),                           -- Storing date of birth as text
    anniversary text,                   -- Storing anniversary date as text
    preferences text,                   -- Storing customer preferences as text
    createddate text,                   -- Storing the record creation date as text
    modifieddate text,                  -- Storing the record modification date as text

    -- Adding audit columns for keeping track of the loaded files and load details
    _stg_file_name text,
    _stg_file_load_ts timestamp,
    _stg_file_md5 text,
    _copy_data_ts timestamp default current_timestamp
)
comment = 'This table is being used as the customer stage/raw table, where the source data is being copied from the internal stage. The data is being kept as-is from the source, with all source columns stored as text. Audit columns are being added to keep track of the file and loading details.';


-- Creating a stream for capturing the newly added customer records from the stage table
create or replace stream stage_sch.customer_stm 
on table stage_sch.customer
append_only = true
comment = 'This append-only stream is being used to capture the newly added customer records from the stage table';


-- Running the COPY command for loading the customer data from the stage file into the stage table
copy into  stage_sch.customer (customerid, name, mobile, email, loginbyusing, gender, dob, anniversary, 
                    preferences, createddate, modifieddate, 
                    _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as customerid,
        t.$2::text as name,
        t.$3::text as mobile,
        t.$4::text as email,
        t.$5::text as loginbyusing,
        t.$6::text as gender,
        t.$7::text as dob,
        t.$8::text as anniversary,
        t.$9::text as preferences,
        t.$10::text as createddate,
        t.$11::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/initial/customer/customers-initial.csv t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;


-- Checking the customer records that are currently being loaded
select * from stage_sch.customer limit 10;

-- Checking the total number of customer records that are currently available
select count(*) from stage_sch.customer; -- 99899

-- Checking the number of records that are currently being captured by the stream
select count(*) from stage_sch.customer_stm; 


-- ==========================================================
-- Part-2: Clean Layer
-- ==========================================================


-- Creating the customer table in the clean layer and converting the source values into suitable data types
CREATE OR REPLACE TABLE CLEAN_SCH.CUSTOMER (
    
    CUSTOMER_SK NUMBER AUTOINCREMENT PRIMARY KEY,                -- Generating an auto-incrementing key for each customer
    CUSTOMER_ID STRING NOT NULL,                                 -- Storing the customer ID
    NAME STRING(100) NOT NULL,                                   -- Storing the customer name
    MOBILE STRING(15)  WITH TAG (common.pii_policy_tag = 'PII'),                                           -- Storing the mobile number
    EMAIL STRING(100) WITH TAG (common.pii_policy_tag = 'EMAIL'),                                           -- Storing the email address
    LOGIN_BY_USING STRING(50),                                   -- Storing the login method
    GENDER STRING(10)  WITH TAG (common.pii_policy_tag = 'PII'),                                           -- Storing the customer gender
    DOB DATE WITH TAG (common.pii_policy_tag = 'PII'),                                                    -- Storing date of birth in DATE format
    ANNIVERSARY DATE,                                            -- Storing anniversary date in DATE format
    PREFERENCES STRING,                                          -- Storing customer preferences
    CREATED_DT TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP,           -- Storing the record creation timestamp
    MODIFIED_DT TIMESTAMP_TZ,                                    -- Storing the record modification timestamp

    -- Adding audit columns for keeping track of the source file and loading information
    _STG_FILE_NAME STRING,                                       -- Keeping the source file name
    _STG_FILE_LOAD_TS TIMESTAMP_NTZ,                             -- Keeping the file loading timestamp
    _STG_FILE_MD5 STRING,                                        -- Keeping the file content hash
    _COPY_DATA_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP        -- Keeping the time when the data is being copied
)
comment = 'This customer table is being used in the clean layer, where the raw customer data is being converted into suitable data types. The data is being populated from the stage layer, and the table is being maintained without SCD Type 2 history.';


-- Creating a stream for capturing insert, update, and delete changes happening in the clean customer table
create or replace stream CLEAN_SCH.customer_stm 
on table CLEAN_SCH.customer
comment = 'This stream is being used to capture insert, update, and delete changes happening in the clean customer table';


-- Loading the initial customer data into the clean table while converting the required columns into suitable data types
insert into clean_sch.customer (
    customer_id,
    name,
    mobile,
    email,
    login_by_using,
    gender,
    dob,
    anniversary,
    preferences,
    created_dt,
    modified_dt,
    _stg_file_name,
    _stg_file_load_ts,
    _stg_file_md5,
    _copy_data_ts
)
select 
    customerid::string,
    name::string,
    mobile::string,
    email::string,
    loginbyusing::string,
    gender::string,
    try_to_date(dob, 'YYYY-MM-DD') as dob,                     -- Converting the date of birth into DATE format
    try_to_date(anniversary, 'YYYY-MM-DD') as anniversary,     -- Converting the anniversary into DATE format
    preferences::string,
    try_to_timestamp_tz(createddate, 'YYYY-MM-DD HH24:MI:SS') as created_dt,  -- Converting the creation date into timestamp format
    try_to_timestamp_tz(modifieddate, 'YYYY-MM-DD HH24:MI:SS') as modified_dt, -- Converting the modification date into timestamp format
    _stg_file_name,
    _stg_file_load_ts,
    _stg_file_md5,
    _copy_data_ts
from stage_sch.customer;


-- Merging the changed customer records from the stream into the clean customer table
MERGE INTO CLEAN_SCH.CUSTOMER AS target
USING (
    SELECT 
        CUSTOMERID::STRING AS CUSTOMER_ID,
        NAME::STRING AS NAME,
        MOBILE::STRING AS MOBILE,
        EMAIL::STRING AS EMAIL,
        LOGINBYUSING::STRING AS LOGIN_BY_USING,
        GENDER::STRING AS GENDER,
        TRY_TO_DATE(DOB, 'YYYY-MM-DD') AS DOB,                     
        TRY_TO_DATE(ANNIVERSARY, 'YYYY-MM-DD') AS ANNIVERSARY,     
        PREFERENCES::STRING AS PREFERENCES,
        TRY_TO_TIMESTAMP_TZ(CREATEDDATE, 'YYYY-MM-DD"T"HH24:MI:SS.FF6') AS CREATED_DT,  
        TRY_TO_TIMESTAMP_TZ(MODIFIEDDATE, 'YYYY-MM-DD"T"HH24:MI:SS.FF6') AS MODIFIED_DT, 
        _STG_FILE_NAME,
        _STG_FILE_LOAD_TS,
        _STG_FILE_MD5,
        _COPY_DATA_TS
    FROM STAGE_SCH.CUSTOMER_STM
) AS source
ON target.CUSTOMER_ID = source.CUSTOMER_ID
WHEN MATCHED THEN
    UPDATE SET 
        target.NAME = source.NAME,
        target.MOBILE = source.MOBILE,
        target.EMAIL = source.EMAIL,
        target.LOGIN_BY_USING = source.LOGIN_BY_USING,
        target.GENDER = source.GENDER,
        target.DOB = source.DOB,
        target.ANNIVERSARY = source.ANNIVERSARY,
        target.PREFERENCES = source.PREFERENCES,
        target.CREATED_DT = source.CREATED_DT,
        target.MODIFIED_DT = source.MODIFIED_DT,
        target._STG_FILE_NAME = source._STG_FILE_NAME,
        target._STG_FILE_LOAD_TS = source._STG_FILE_LOAD_TS,
        target._STG_FILE_MD5 = source._STG_FILE_MD5,
        target._COPY_DATA_TS = source._COPY_DATA_TS
WHEN NOT MATCHED THEN
    INSERT (
        CUSTOMER_ID,
        NAME,
        MOBILE,
        EMAIL,
        LOGIN_BY_USING,
        GENDER,
        DOB,
        ANNIVERSARY,
        PREFERENCES,
        CREATED_DT,
        MODIFIED_DT,
        _STG_FILE_NAME,
        _STG_FILE_LOAD_TS,
        _STG_FILE_MD5,
        _COPY_DATA_TS
    )
    VALUES (
        source.CUSTOMER_ID,
        source.NAME,
        source.MOBILE,
        source.EMAIL,
        source.LOGIN_BY_USING,
        source.GENDER,
        source.DOB,
        source.ANNIVERSARY,
        source.PREFERENCES,
        source.CREATED_DT,
        source.MODIFIED_DT,
        source._STG_FILE_NAME,
        source._STG_FILE_LOAD_TS,
        source._STG_FILE_MD5,
        source._COPY_DATA_TS
    );


-- Creating the customer dimension table for maintaining customer history using SCD Type 2
CREATE OR REPLACE TABLE CONSUMPTION_SCH.CUSTOMER_DIM (
    CUSTOMER_HK NUMBER PRIMARY KEY,               -- Generating a hash key for identifying each customer version
    CUSTOMER_ID STRING NOT NULL,                                 -- Storing the natural customer ID
    NAME STRING(100) NOT NULL,                                   -- Storing the customer name
    MOBILE STRING(15) WITH TAG (common.pii_policy_tag = 'PII'),                                           -- Storing the mobile number
    EMAIL STRING(100) WITH TAG (common.pii_policy_tag = 'EMAIL'),                                           -- Storing the email address
    LOGIN_BY_USING STRING(50),                                   -- Storing the login method
    GENDER STRING(10) WITH TAG (common.pii_policy_tag = 'PII'),                                           -- Storing the customer gender
    DOB DATE WITH TAG (common.pii_policy_tag = 'PII'),                                                    -- Storing date of birth
    ANNIVERSARY DATE,                                            -- Storing the anniversary date
    PREFERENCES STRING,                                          -- Storing customer preferences
    EFF_START_DATE TIMESTAMP_TZ,                                 -- Recording when the customer version is becoming active
    EFF_END_DATE TIMESTAMP_TZ,                                   -- Recording when the customer version is becoming inactive
    IS_CURRENT BOOLEAN                                           -- Indicating whether the record is currently active
)
COMMENT = 'This customer dimension is being maintained using SCD Type 2 so that changes in customer information are being tracked as historical records.';


-- Checking the customer dimension records and viewing them in gender order
select *
from consumption_sch.customer_dim
order by gender;


-- Merging the customer changes from the clean stream into the customer dimension
MERGE INTO 
    CONSUMPTION_SCH.CUSTOMER_DIM AS target
USING 
    CLEAN_SCH.CUSTOMER_STM AS source
ON 
    target.CUSTOMER_ID = source.CUSTOMER_ID AND
    target.NAME = source.NAME AND
    target.MOBILE = source.MOBILE AND
    target.EMAIL = source.EMAIL AND
    target.LOGIN_BY_USING = source.LOGIN_BY_USING AND
    target.GENDER = source.GENDER AND
    target.DOB = source.DOB AND
    target.ANNIVERSARY = source.ANNIVERSARY AND
    target.PREFERENCES = source.PREFERENCES
WHEN MATCHED 
    AND source.METADATA$ACTION = 'DELETE' AND source.METADATA$ISUPDATE = 'TRUE' THEN
    -- Closing the validity period of the existing customer record
    UPDATE SET 
        target.EFF_END_DATE = CURRENT_TIMESTAMP(),
        target.IS_CURRENT = FALSE
WHEN NOT MATCHED 
    AND source.METADATA$ACTION = 'INSERT' AND source.METADATA$ISUPDATE = 'TRUE' THEN
    -- Inserting the updated customer version and starting a new validity period
    INSERT (
        CUSTOMER_HK,
        CUSTOMER_ID,
        NAME,
        MOBILE,
        EMAIL,
        LOGIN_BY_USING,
        GENDER,
        DOB,
        ANNIVERSARY,
        PREFERENCES,
        EFF_START_DATE,
        EFF_END_DATE,
        IS_CURRENT
    )
    VALUES (
        hash(SHA1_hex(CONCAT(source.CUSTOMER_ID, source.NAME, source.MOBILE, 
            source.EMAIL, source.LOGIN_BY_USING, source.GENDER, source.DOB, 
            source.ANNIVERSARY, source.PREFERENCES))),
        source.CUSTOMER_ID,
        source.NAME,
        source.MOBILE,
        source.EMAIL,
        source.LOGIN_BY_USING,
        source.GENDER,
        source.DOB,
        source.ANNIVERSARY,
        source.PREFERENCES,
        CURRENT_TIMESTAMP(),
        NULL,
        TRUE
    )
WHEN NOT MATCHED 
    AND source.METADATA$ACTION = 'INSERT' AND source.METADATA$ISUPDATE = 'FALSE' THEN
    -- Inserting a new customer record and starting its validity period
    INSERT (
        CUSTOMER_HK,
        CUSTOMER_ID,
        NAME,
        MOBILE,
        EMAIL,
        LOGIN_BY_USING,
        GENDER,
        DOB,
        ANNIVERSARY,
        PREFERENCES,
        EFF_START_DATE,
        EFF_END_DATE,
        IS_CURRENT
    )
    VALUES (
        hash(SHA1_hex(CONCAT(source.CUSTOMER_ID, source.NAME, source.MOBILE, 
            source.EMAIL, source.LOGIN_BY_USING, source.GENDER, source.DOB, 
            source.ANNIVERSARY, source.PREFERENCES))),
        source.CUSTOMER_ID,
        source.NAME,
        source.MOBILE,
        source.EMAIL,
        source.LOGIN_BY_USING,
        source.GENDER,
        source.DOB,
        source.ANNIVERSARY,
        source.PREFERENCES,
        CURRENT_TIMESTAMP(),
        NULL,
        TRUE
    );


// ----------------------------------------------------------
// ----------------------------------------------------------
-- Checking the available customer delta files before loading them

list @stage_sch.csv_stg/delta/Customer/;


-- Loading the first customer delta file into the stage table
copy into  stage_sch.customer (customerid, name, mobile, email, loginbyusing, gender, dob, anniversary, 
                    preferences, createddate, modifieddate, 
                    _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as customerid,
        t.$2::text as name,
        t.$3::text as mobile,
        t.$4::text as email,
        t.$5::text as loginbyusing,
        t.$6::text as gender,
        t.$7::text as dob,
        t.$8::text as anniversary,
        t.$9::text as preferences,
        t.$10::text as createddate,
        t.$11::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/delta/Customer/day-01-insert-customer.csv t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;


-- ------------------------------------------------
-- Part-2: Loading the delta data
-- ------------------------------------------------


-- Checking the customer delta files that are currently available for loading
list @stage_sch.csv_stg/delta/customer/;


-- Loading the second customer delta file into the stage table
copy into  stage_sch.customer (customerid, name, mobile, email, loginbyusing, gender, dob, anniversary, 
                    preferences, createddate, modifieddate, 
                    _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as customerid,
        t.$2::text as name,
        t.$3::text as mobile,
        t.$4::text as email,
        t.$5::text as loginbyusing,
        t.$6::text as gender,
        t.$7::text as dob,
        t.$8::text as anniversary,
        t.$9::text as preferences,
        t.$10::text as createddate,
        t.$11::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/delta/Customer/day-02-insert-update.csv t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;
