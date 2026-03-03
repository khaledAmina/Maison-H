WITH sales AS (
    SELECT * FROM {{ ref('int_sales_transactions') }}
),
clients AS (
    SELECT * FROM {{ ref('int_clients_deduplicated') }}
)

SELECT 
    s.transaction_id,
    s.transaction_date,
    c.client_key, -- On utilise la clé du Golden Record
    s.store_key,
    s.product_key,
    s.quantity,
    s.amount_original,
    s.currency_code,
    s.amount_eur, -- Montant converti via la macro
    s.is_return
FROM sales s
LEFT JOIN clients c ON s.client_id = c.source_client_id