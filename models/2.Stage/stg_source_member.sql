{{ config(
    materialized = 'incremental',
    incremental_strategy = 'delete+insert',
    unique_key = 'DBT_UNIQUE_KEY'
) }}

with source_data as (

    select
        ID as SOURCE_PERSON_KEY,
        EMAIL_ADDRESS,
        FIRST_NAME,
        LAST_NAME,
        PHONE_NUMBER,
        MEMBERID,
        MEMBERIDSHORT,
        EMPLOYER_ID,
        CLIENTID,
        FAMILY_ID,
        PLAN_ID,
        CARDID,
        ALTGROUPID,
        ALTMEMBERID,
        MEMBERRELATIONSHIPCODE_ID,
        NETWORKPREFIX,
        ISACTIVE,
        LAST_UPDATED,
        DATE_INACTIVE
    from {{ source('DBT_PRACTICE', 'SOURCE_MEMBER') }}

),

target_data as (

    {% if is_incremental() %}

        select *
        from {{ this }}

    {% else %}

        select
            null as DBT_UNIQUE_KEY,
            null as MEMBER_SK,
            null as SOURCE_PERSON_KEY,
            null as EMAIL_ADDRESS,
            null as FIRST_NAME,
            null as LAST_NAME,
            null as PHONE_NUMBER,
            null as MEMBERID,
            null as MEMBERIDSHORT,
            null as EMPLOYER_ID,
            null as CLIENTID,
            null as FAMILY_ID,
            null as PLAN_ID,
            null as CARDID,
            null as ALTGROUPID,
            null as ALTMEMBERID,
            null as MEMBERRELATIONSHIPCODE_ID,
            null as NETWORKPREFIX,
            null as ISACTIVE,
            null as ROW_CREATED_DATE,
            null as ROW_UPDATED_DATE,
            null as ROW_MODIFIED_DATE,
            null as LAST_UPDATED,
            null as DATE_INACTIVE
        where 1 = 0

    {% endif %}

),

active_target as (

    select *
    from target_data
    where ISACTIVE = 1
      and DATE_INACTIVE is null

),

existing_target as (

    select distinct SOURCE_PERSON_KEY
    from target_data

),

change_check as (

    select
        s.*,

        t.DBT_UNIQUE_KEY as EXISTING_DBT_UNIQUE_KEY,
        t.MEMBER_SK as EXISTING_MEMBER_SK,
        t.ROW_CREATED_DATE as EXISTING_ROW_CREATED_DATE,

        case
            when e.SOURCE_PERSON_KEY is null then 'NEW'

            when t.SOURCE_PERSON_KEY is null then 'NO_CHANGE'

            when s.ISACTIVE = 0 then 'NO_CHANGE'

            when
                coalesce(to_varchar(s.MEMBERID), '') <> coalesce(to_varchar(t.MEMBERID), '')
                or coalesce(to_varchar(s.MEMBERIDSHORT), '') <> coalesce(to_varchar(t.MEMBERIDSHORT), '')
                or coalesce(to_varchar(s.EMPLOYER_ID), '') <> coalesce(to_varchar(t.EMPLOYER_ID), '')
                or coalesce(to_varchar(s.CLIENTID), '') <> coalesce(to_varchar(t.CLIENTID), '')
                or coalesce(to_varchar(s.FAMILY_ID), '') <> coalesce(to_varchar(t.FAMILY_ID), '')
                or coalesce(to_varchar(s.PLAN_ID), '') <> coalesce(to_varchar(t.PLAN_ID), '')
                or coalesce(to_varchar(s.CARDID), '') <> coalesce(to_varchar(t.CARDID), '')
                or coalesce(to_varchar(s.ALTGROUPID), '') <> coalesce(to_varchar(t.ALTGROUPID), '')
                or coalesce(to_varchar(s.ALTMEMBERID), '') <> coalesce(to_varchar(t.ALTMEMBERID), '')
                or coalesce(to_varchar(s.MEMBERRELATIONSHIPCODE_ID), '') <> coalesce(to_varchar(t.MEMBERRELATIONSHIPCODE_ID), '')
                or coalesce(to_varchar(s.NETWORKPREFIX), '') <> coalesce(to_varchar(t.NETWORKPREFIX), '')
            then 'SCD2_CHANGE'

            when
                coalesce(to_varchar(s.EMAIL_ADDRESS), '') <> coalesce(to_varchar(t.EMAIL_ADDRESS), '')
                or coalesce(to_varchar(s.FIRST_NAME), '') <> coalesce(to_varchar(t.FIRST_NAME), '')
                or coalesce(to_varchar(s.LAST_NAME), '') <> coalesce(to_varchar(t.LAST_NAME), '')
                or coalesce(to_varchar(s.PHONE_NUMBER), '') <> coalesce(to_varchar(t.PHONE_NUMBER), '')
            then 'SCD1_CHANGE'

            else 'NO_CHANGE'
        end as CHANGE_TYPE

    from source_data s
    left join active_target t
        on s.SOURCE_PERSON_KEY = t.SOURCE_PERSON_KEY
    left join existing_target e
        on s.SOURCE_PERSON_KEY = e.SOURCE_PERSON_KEY

),

max_key as (

    select coalesce(max(MEMBER_SK), 0) as MAX_MEMBER_SK
    from target_data

),

new_rows as (

    select
        'KEY_' || to_varchar(max_key.MAX_MEMBER_SK + row_number() over(order by SOURCE_PERSON_KEY)) as DBT_UNIQUE_KEY,

        max_key.MAX_MEMBER_SK + row_number() over(order by SOURCE_PERSON_KEY) as MEMBER_SK,

        SOURCE_PERSON_KEY,
        EMAIL_ADDRESS,
        FIRST_NAME,
        LAST_NAME,
        PHONE_NUMBER,
        MEMBERID,
        MEMBERIDSHORT,
        EMPLOYER_ID,
        CLIENTID,
        FAMILY_ID,
        PLAN_ID,
        CARDID,
        ALTGROUPID,
        ALTMEMBERID,
        MEMBERRELATIONSHIPCODE_ID,
        NETWORKPREFIX,
        ISACTIVE,

        current_date as ROW_CREATED_DATE,
        current_date as ROW_UPDATED_DATE,
        current_date as ROW_MODIFIED_DATE,
        coalesce(LAST_UPDATED, current_date) as LAST_UPDATED,
        DATE_INACTIVE

    from change_check
    cross join max_key
    where CHANGE_TYPE = 'NEW'

),

scd1_updated_rows as (

    select
        EXISTING_DBT_UNIQUE_KEY as DBT_UNIQUE_KEY,
        EXISTING_MEMBER_SK as MEMBER_SK,

        SOURCE_PERSON_KEY,
        EMAIL_ADDRESS,
        FIRST_NAME,
        LAST_NAME,
        PHONE_NUMBER,
        MEMBERID,
        MEMBERIDSHORT,
        EMPLOYER_ID,
        CLIENTID,
        FAMILY_ID,
        PLAN_ID,
        CARDID,
        ALTGROUPID,
        ALTMEMBERID,
        MEMBERRELATIONSHIPCODE_ID,
        NETWORKPREFIX,
        1 as ISACTIVE,

        EXISTING_ROW_CREATED_DATE as ROW_CREATED_DATE,
        current_date as ROW_UPDATED_DATE,
        current_date as ROW_MODIFIED_DATE,
        current_date as LAST_UPDATED,
        null as DATE_INACTIVE

    from change_check
    where CHANGE_TYPE = 'SCD1_CHANGE'

),

expired_scd2_rows as (

    select
        t.DBT_UNIQUE_KEY,
        t.MEMBER_SK,
        t.SOURCE_PERSON_KEY,
        t.EMAIL_ADDRESS,
        t.FIRST_NAME,
        t.LAST_NAME,
        t.PHONE_NUMBER,
        t.MEMBERID,
        t.MEMBERIDSHORT,
        t.EMPLOYER_ID,
        t.CLIENTID,
        t.FAMILY_ID,
        t.PLAN_ID,
        t.CARDID,
        t.ALTGROUPID,
        t.ALTMEMBERID,
        t.MEMBERRELATIONSHIPCODE_ID,
        t.NETWORKPREFIX,

        0 as ISACTIVE,

        t.ROW_CREATED_DATE,
        current_date as ROW_UPDATED_DATE,
        current_date as ROW_MODIFIED_DATE,
        t.LAST_UPDATED,
        current_date as DATE_INACTIVE

    from active_target t
    inner join change_check s
        on t.SOURCE_PERSON_KEY = s.SOURCE_PERSON_KEY
    where s.CHANGE_TYPE = 'SCD2_CHANGE'

),

new_scd2_rows as (

    select
        'KEY_' || to_varchar(
            max_key.MAX_MEMBER_SK
            + (
                select count(*)
                from change_check
                where CHANGE_TYPE = 'NEW'
              )
            + row_number() over(order by SOURCE_PERSON_KEY)
        ) as DBT_UNIQUE_KEY,

        max_key.MAX_MEMBER_SK
            + (
                select count(*)
                from change_check
                where CHANGE_TYPE = 'NEW'
              )
            + row_number() over(order by SOURCE_PERSON_KEY) as MEMBER_SK,

        SOURCE_PERSON_KEY,
        EMAIL_ADDRESS,
        FIRST_NAME,
        LAST_NAME,
        PHONE_NUMBER,
        MEMBERID,
        MEMBERIDSHORT,
        EMPLOYER_ID,
        CLIENTID,
        FAMILY_ID,
        PLAN_ID,
        CARDID,
        ALTGROUPID,
        ALTMEMBERID,
        MEMBERRELATIONSHIPCODE_ID,
        NETWORKPREFIX,

        1 as ISACTIVE,

        current_date as ROW_CREATED_DATE,
        current_date as ROW_UPDATED_DATE,
        current_date as ROW_MODIFIED_DATE,
        current_date as LAST_UPDATED,
        null as DATE_INACTIVE

    from change_check
    cross join max_key
    where CHANGE_TYPE = 'SCD2_CHANGE'

)

select * from new_rows

union all

select * from scd1_updated_rows

union all

select * from expired_scd2_rows

union all

select * from new_scd2_rows