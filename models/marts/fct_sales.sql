{{
  config(
    materialized='incremental',
    unique_key='transaction_id',
    incremental_strategy='merge',
    cluster_by=['date_key', 'store_key']
  )
}}

WITH sales_transactions AS (
    SELECT * FROM {{ ref('int_sales_transactions') }}
    {% if is_incremental() %}
     
      WHERE transaction_date >= (SELECT MAX(date_key) FROM {{ this }})
    {% endif %}
),

clients AS (
    -- On récupère la clé du Golden Record pour faire le lien avec la dimension client
    SELECT client_key, source_client_id FROM {{ ref('int_clients_deduplicated') }}
)

SELECT 
    s.transaction_id,
    COALESCE(c.client_key, 'ANONYMOUS') AS client_key,
    s.product_key,
    s.store_key,
    s.transaction_date AS date_key,
    s.amount_original,
    s.currency_code,
    s.amount_eur, -- Calculé via la macro convert_to_eur en amont
    s.is_return,
    s.channel
FROM sales_transactions s
LEFT JOIN clients c ON s.client_id = c.source_client_id