WITH stg_products AS (
    SELECT * FROM {{ ref('stg_products_catalog') }}
)

SELECT
    product_key,
    product_name,
    metier,
    category,
    collection,
    unit_price_eur AS price_eur
FROM stg_products