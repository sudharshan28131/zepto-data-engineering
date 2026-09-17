use role sysadmin;
use database sandbox;
use schema stage_sch;
use warehouse adhoc_wh;


-- Creating the menu table in the stage layer and storing the source data as text
create or replace table stage_sch.menu (
    menuid text comment 'Primary Key (Source System)',                   -- Storing menu ID as text
    restaurantid text comment 'Restaurant FK(Source System)',             -- Storing restaurant reference ID as text
    itemname text,                 -- Storing menu item name as text
    description text,              -- Storing menu item description as text
    price text,                    -- Storing price as text
    category text,                 -- Storing food category as text
    availability text,             -- Storing availability status as text
    itemtype text,                 -- Storing item type as text
    createddate text,              -- Storing creation date as text
    modifieddate text,             -- Storing modification date as text

    -- Adding audit columns for tracking file and data loading details
    _stg_file_name text,
    _stg_file_load_ts timestamp,
    _stg_file_md5 text,
    _copy_data_ts timestamp default current_timestamp
)
comment = 'This menu table is being used as the stage/raw layer, where the source data is being copied from the internal stage. The source data is being kept as-is, while audit columns are being added for tracking file and loading details.';


-- Creating a stream for capturing newly added menu changes
create or replace stream stage_sch.menu_stm 
on table stage_sch.menu
append_only = true
comment = 'This append-only stream is being used for capturing newly added menu records and delta data';


-- Checking the menu files that are currently available in the stage
list @stage_sch.csv_stg/initial/menu;


-- Loading the initial menu data from the internal stage into the stage table
copy into stage_sch.menu (menuid, restaurantid, itemname, description, price, category, 
                availability, itemtype, createddate, modifieddate,
                _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as menuid,
        t.$2::text as restaurantid,
        t.$3::text as itemname,
        t.$4::text as description,
        t.$5::text as price,
        t.$6::text as category,
        t.$7::text as availability,
        t.$8::text as itemtype,
        t.$9::text as createddate,
        t.$10::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/initial/Menu t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;


-- Checking the menu records that are currently being loaded
select * from menu;


-- Checking the recent COPY INTO history for the menu table
select *
from table(information_schema.copy_history(table_name=>'MENU', start_time=> dateadd(hours, -1, current_timestamp())));


-- ==========================================================
-- 2nd Layer: Clean Layer
-- ==========================================================


-- Creating the menu table in the clean layer and converting the source values into suitable data types
CREATE OR REPLACE TABLE clean_sch.menu (
    Menu_SK INT AUTOINCREMENT PRIMARY KEY comment 'Surrogate Key (EDW)',  -- Generating an auto-incrementing key for internal tracking
    Menu_ID INT NOT NULL UNIQUE comment 'Primary Key (Source System)' ,             -- Storing the unique menu ID
    Restaurant_ID_FK INT comment 'Restaurant FK(Source System)' ,                      -- Storing the restaurant reference ID
    Item_Name STRING not null,                        -- Storing the menu item name
    Description STRING not null,                     -- Storing the menu item description
    Price DECIMAL(10, 2) not null,                   -- Storing the price with two decimal places
    Category STRING,                        -- Storing the food category
    Availability BOOLEAN,                   -- Storing the availability status
    Item_Type STRING,                        -- Storing the dietary classification
    Created_dt TIMESTAMP_NTZ,               -- Storing the record creation timestamp
    Modified_dt TIMESTAMP_NTZ,              -- Storing the record modification timestamp

    -- Adding audit columns for tracking the source file and loading information
    _STG_FILE_NAME STRING,                  -- Storing the source file name
    _STG_FILE_LOAD_TS TIMESTAMP_NTZ,        -- Storing the stage file loading timestamp
    _STG_FILE_MD5 STRING,                   -- Storing the source file MD5 hash
    _COPY_DATA_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP -- Storing the time when data is being copied into the clean layer
)
comment = 'This menu table is being used in the clean layer, where the raw menu data is being converted into suitable data types. The data is being populated from the stage layer, while audit information is being maintained for tracking.';


-- Creating a stream for capturing changes happening in the clean menu table
create or replace stream CLEAN_SCH.menu_stm 
on table CLEAN_SCH.menu
comment = 'This stream is being used for capturing insert, update, and delete changes happening in the clean menu table';


-- Merging the menu data from the stage layer into the clean table
MERGE INTO clean_sch.menu AS target
USING (
    SELECT 
        TRY_CAST(menuid AS INT) AS Menu_ID,
        TRY_CAST(restaurantid AS INT) AS Restaurant_ID_FK,
        TRIM(itemname) AS Item_Name,
        TRIM(description) AS Description,
        TRY_CAST(price AS DECIMAL(10, 2)) AS Price,
        TRIM(category) AS Category,
        CASE 
            WHEN LOWER(availability) = 'true' THEN TRUE
            WHEN LOWER(availability) = 'false' THEN FALSE
            ELSE NULL
        END AS Availability,
        TRIM(itemtype) AS Item_Type,
        TRY_CAST(createddate AS TIMESTAMP_NTZ) AS Created_dt,
        TRY_CAST(modifieddate AS TIMESTAMP_NTZ) AS Modified_dt,
        _stg_file_name,
        _stg_file_load_ts,
        _stg_file_md5,
        _copy_data_ts
    FROM stage_sch.menu
) AS source
ON target.Menu_ID = source.Menu_ID

-- Updating the existing menu record when changes are being detected
WHEN MATCHED THEN
    UPDATE SET
        Restaurant_ID_FK = source.Restaurant_ID_FK,
        Item_Name = source.Item_Name,
        Description = source.Description,
        Price = source.Price,
        Category = source.Category,
        Availability = source.Availability,
        Item_Type = source.Item_Type,
        Created_dt = source.Created_dt,  
        Modified_dt = source.Modified_dt,  
        _STG_FILE_NAME = source._stg_file_name,
        _STG_FILE_LOAD_TS = source._stg_file_load_ts,
        _STG_FILE_MD5 = source._stg_file_md5,
        _COPY_DATA_TS = CURRENT_TIMESTAMP

-- Inserting the menu record when a new menu item is being found
WHEN NOT MATCHED THEN
    INSERT (
        Menu_ID,
        Restaurant_ID_FK,
        Item_Name,
        Description,
        Price,
        Category,
        Availability,
        Item_Type,
        Created_dt, 
        Modified_dt,  
        _STG_FILE_NAME,
        _STG_FILE_LOAD_TS,
        _STG_FILE_MD5,
        _COPY_DATA_TS
    )
    VALUES (
        source.Menu_ID,
        source.Restaurant_ID_FK,
        source.Item_Name,
        source.Description,
        source.Price,
        source.Category,
        source.Availability,
        source.Item_Type,
        source.Created_dt,  
        source.Modified_dt,  
        source._stg_file_name,
        source._stg_file_load_ts,
        source._stg_file_md5,
        CURRENT_TIMESTAMP
    );


-- Creating the menu dimension for maintaining historical menu information using SCD Type 2
CREATE OR REPLACE TABLE consumption_sch.menu_dim (
    Menu_Dim_HK NUMBER primary key comment 'Menu Dim HK (EDW)',                         -- Generating a hash key for the menu dimension
    Menu_ID INT NOT NULL comment 'Primary Key (Source System)',                       -- Storing the source menu ID
    Restaurant_ID_FK INT NOT NULL comment 'Restaurant FK (Source System)',                          -- Storing the restaurant reference ID
    Item_Name STRING,                            -- Storing the menu item name
    Description STRING,                         -- Storing the menu item description
    Price DECIMAL(10, 2),                       -- Storing the menu item price
    Category STRING,                            -- Storing the food category
    Availability BOOLEAN,                       -- Storing the availability status
    Item_Type STRING,                           -- Storing the item type
    EFF_START_DATE TIMESTAMP_NTZ,               -- Recording when the menu version is becoming active
    EFF_END_DATE TIMESTAMP_NTZ,                 -- Recording when the menu version is becoming inactive
    IS_CURRENT BOOLEAN                         -- Indicating whether the menu record is currently active
)
COMMENT = 'This menu dimension is being used for maintaining historical changes using SCD Type 2. Effective dates and the current flag are being used for identifying active and historical menu records, while a hash key is being generated for the dimension.';


-- Merging menu changes from the clean stream into the menu dimension
MERGE INTO 
    consumption_sch.MENU_DIM AS target
USING 
    CLEAN_SCH.MENU_STM AS source
ON 
    target.Menu_ID = source.Menu_ID AND
    target.Restaurant_ID_FK = source.Restaurant_ID_FK AND
    target.Item_Name = source.Item_Name AND
    target.Description = source.Description AND
    target.Price = source.Price AND
    target.Category = source.Category AND
    target.Availability = source.Availability AND
    target.Item_Type = source.Item_Type

WHEN MATCHED 
    AND source.METADATA$ACTION = 'DELETE' 
    AND source.METADATA$ISUPDATE = 'TRUE' THEN

    -- Closing the validity period when the existing menu record is being updated
    UPDATE SET 
        target.EFF_END_DATE = CURRENT_TIMESTAMP(),
        target.IS_CURRENT = FALSE

WHEN NOT MATCHED 
    AND source.METADATA$ACTION = 'INSERT' 
    AND source.METADATA$ISUPDATE = 'TRUE' THEN

    -- Inserting the updated menu version and starting a new validity period
    INSERT (
        Menu_Dim_HK,               -- Generating the hash key
        Menu_ID,
        Restaurant_ID_FK,
        Item_Name,
        Description,
        Price,
        Category,
        Availability,
        Item_Type,
        EFF_START_DATE,
        EFF_END_DATE,
        IS_CURRENT
    )
    VALUES (
        hash(SHA1_hex(CONCAT(source.Menu_ID, source.Restaurant_ID_FK, 
            source.Item_Name, source.Description, source.Price, 
            source.Category, source.Availability, source.Item_Type))),  -- Generating the hash key
        source.Menu_ID,
        source.Restaurant_ID_FK,
        source.Item_Name,
        source.Description,
        source.Price,
        source.Category,
        source.Availability,
        source.Item_Type,
        CURRENT_TIMESTAMP(),       -- Setting the effective start date
        NULL,                      -- Keeping the effective end date as NULL for the current record
        TRUE                       -- Marking the new record as current
    )

WHEN NOT MATCHED 
    AND source.METADATA$ACTION = 'INSERT' 
    AND source.METADATA$ISUPDATE = 'FALSE' THEN

    -- Inserting a new menu record and starting its validity period
    INSERT (
        Menu_Dim_HK,               -- Generating the hash key
        Menu_ID,
        Restaurant_ID_FK,
        Item_Name,
        Description,
        Price,
        Category,
        Availability,
        Item_Type,
        EFF_START_DATE,
        EFF_END_DATE,
        IS_CURRENT
    )
    VALUES (
        hash(SHA1_hex(CONCAT(source.Menu_ID, source.Restaurant_ID_FK, 
            source.Item_Name, source.Description, source.Price, 
            source.Category, source.Availability, source.Item_Type))),  -- Generating the hash key
        source.Menu_ID,
        source.Restaurant_ID_FK,
        source.Item_Name,
        source.Description,
        source.Price,
        source.Category,
        source.Availability,
        source.Item_Type,
        CURRENT_TIMESTAMP(),       -- Setting the effective start date
        NULL,                      -- Keeping the effective end date as NULL for the current record
        TRUE                       -- Marking the new record as current
    );


-- Checking the available menu delta files before loading new changes
list @stage_sch.csv_stg/delta/Menu;


-- Loading the menu delta file into the stage table
copy into stage_sch.menu (menuid, restaurantid, itemname, description, price, category, 
                availability, itemtype, createddate, modifieddate,
                _stg_file_name, _stg_file_load_ts, _stg_file_md5, _copy_data_ts)
from (
    select 
        t.$1::text as menuid,
        t.$2::text as restaurantid,
        t.$3::text as itemname,
        t.$4::text as description,
        t.$5::text as price,
        t.$6::text as category,
        t.$7::text as availability,
        t.$8::text as itemtype,
        t.$9::text as createddate,
        t.$10::text as modifieddate,
        metadata$filename as _stg_file_name,
        metadata$file_last_modified as _stg_file_load_ts,
        metadata$file_content_key as _stg_file_md5,
        current_timestamp as _copy_data_ts
    from @stage_sch.csv_stg/delta/Menu/day-02-menu-data.csv t
)
file_format = (format_name = 'stage_sch.csv_file_format')
on_error = abort_statement;


-- Checking the menu dimension records that are currently being maintained
select * 
from consumption_sch.menu_dim
order by menu_id
limit 10;
