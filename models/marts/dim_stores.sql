WITH stg_stores AS (
    SELECT * FROM {{ ref('stg_stores') }}
)

SELECT
    store_key,
    store_name,
    city,
    country,
    region,
    channel 
FROM stg_stores