WITH source AS (
    SELECT * FROM {{ source('maison_h_raw', 'src_stores') }}
),

renamed AS (
    SELECT
        store_id AS store_key,
        store_name,
        city,
        country,
        region,
        UPPER(channel) AS channel
    FROM source
)

SELECT * FROM renamed