SELECT
    DATE_TRUNC('month', f.DATE_KEY) AS sales_month,
    s.STORE_NAME,
    p.METIER,
    -- CA Brut
    SUM(f.AMOUNT_EUR) AS turnover_gross,
    -- CA Net (hors retours)
    SUM(CASE WHEN f.IS_RETURN = FALSE THEN f.AMOUNT_EUR ELSE 0 END) AS turnover_net,
    -- Volumes
    COUNT(DISTINCT f.TRANSACTION_ID) AS nb_transactions,
    COUNT(DISTINCT f.CLIENT_KEY) AS nb_unique_customers,
    -- Panier Moyen (CA Net / Transactions de vente)
    DIV0(
        SUM(CASE WHEN f.IS_RETURN = FALSE THEN f.AMOUNT_EUR ELSE 0 END), 
        COUNT(DISTINCT CASE WHEN f.IS_RETURN = FALSE THEN f.TRANSACTION_ID END)
    ) AS average_basket
FROM {{ ref('fct_sales') }} f
LEFT JOIN {{ ref('dim_stores') }} s ON f.STORE_KEY = s.STORE_KEY
LEFT JOIN {{ ref('dim_products') }} p ON f.PRODUCT_KEY = p.PRODUCT_KEY
GROUP BY 1, 2, 3