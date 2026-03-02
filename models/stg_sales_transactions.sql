WITH source AS (
    SELECT * FROM {{ source('maison_h_raw', 'src_sales_transactions') }}
),

exchange_rates AS (
    SELECT * FROM {{ source('maison_h_raw','src_exchange_rates') }}
),

renamed AS (
    SELECT
        s.trans_id AS transaction_id,
        s.client_id,
        s.store_id AS store_key,
        s.product_ref AS product_key,
        CAST(s.quantity AS INT) AS quantity,
        CAST(s.amount AS DECIMAL(12,2)) AS amount_original,
        s.currency AS currency_code,
        CAST(s.trans_date AS DATE) AS transaction_date,
        s.channel, 
        
       
        r.rate_to_eur,

        {{ convert_to_eur('s.amount', 'r.rate_to_eur') }} AS amount_eur, -- 
        
        -- Flag de retour et validité
        CASE WHEN s.amount < 0 THEN TRUE ELSE FALSE END AS is_return,
        CASE WHEN r.rate_to_eur IS NULL AND s.currency != 'EUR' THEN FALSE ELSE TRUE END AS is_currency_valid
        
    FROM source s
    LEFT JOIN exchange_rates r 
        ON s.currency = r.currency_code
)

SELECT * FROM renamed