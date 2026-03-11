WITH client_stats AS (
    SELECT
        CLIENT_KEY,
        SUM(CASE WHEN IS_RETURN = FALSE THEN AMOUNT_EUR ELSE 0 END) AS ltv,
        MAX(DATE_KEY) AS last_purchase_date,
        COUNT(DISTINCT TRANSACTION_ID) AS total_transactions,
        COUNT(DISTINCT STORE_KEY) AS stores_visited
    FROM {{ ref('fct_sales') }}
    GROUP BY 1
),

-- Calcul du métier de prédilection (le plus gros CA par client)
metier_rank AS (
    SELECT 
        f.CLIENT_KEY,
        p.METIER,
        SUM(f.AMOUNT_EUR) as metier_ca,
        ROW_NUMBER() OVER (
            PARTITION BY f.CLIENT_KEY 
            ORDER BY SUM(f.AMOUNT_EUR) DESC, COUNT(*) DESC, p.METIER ASC
        ) as rank_metier
    FROM {{ ref('fct_sales') }} f
    JOIN {{ ref('dim_products') }} p ON f.PRODUCT_KEY = p.PRODUCT_KEY
    GROUP BY 1, 2
)

SELECT 
    c.CLIENT_KEY,
    c.EMAIL_HASH,
    c.VIP_STATUS_SOURCE,
    s.ltv,
    s.last_purchase_date,
    s.total_transactions,
    s.stores_visited,
    m.METIER AS favorite_metier,
    -- Segmentation dynamique via variables dbt
    CASE 
        WHEN s.ltv >= {{ var('vic_threshold', 50000) }} THEN 'V.I.C'
        WHEN s.ltv >= {{ var('top_client_threshold', 10000) }} THEN 'Top Client'
        WHEN s.ltv >= {{ var('client_threshold', 2000) }} THEN 'Client'
        ELSE 'Prospect'
    END AS segmentation_label
FROM {{ ref('dim_clients') }} c
LEFT JOIN client_stats s ON c.CLIENT_KEY = s.CLIENT_KEY
LEFT JOIN metier_rank m ON c.CLIENT_KEY = m.CLIENT_KEY AND m.rank_metier = 1