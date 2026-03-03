WITH source AS (
    SELECT * FROM {{ source('maison_h_raw', 'src_products_catalog') }}
),

renamed AS (
    SELECT
        sku AS product_key,
        product_name,
        INITCAP(metier) AS metier,
        category,
        collection,
        CAST(price_eur AS DECIMAL(10,2)) AS unit_price_eur -- Typage monétaire 
    FROM source
)

SELECT * FROM renamed