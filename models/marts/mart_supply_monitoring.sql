WITH sales_30d AS (
    SELECT
        PRODUCT_KEY,
        SUM(CASE WHEN IS_RETURN = FALSE THEN 1 ELSE 0 END) / 30 AS avg_daily_sales_30d,
        SUM(CASE WHEN IS_RETURN = TRUE THEN 1 ELSE 0 END) as total_returns
    FROM {{ ref('fct_sales') }}
    WHERE DATE_KEY >= DATEADD('day', -30, CURRENT_DATE())
    GROUP BY 1
)

SELECT
    p.PRODUCT_KEY,
    p.PRODUCT_NAME,
    p.METIER,
    p.CATEGORY,
    -- Simulation d'un stock fixe pour l'exercice (ou jointure avec table stock si existante)
    100 AS current_stock, 
    s.avg_daily_sales_30d,
    DIV0(100, s.avg_daily_sales_30d) AS stock_coverage_days,
    CASE 
        WHEN DIV0(100, s.avg_daily_sales_30d) < 7 THEN 'REAPPRO'
        WHEN DIV0(100, s.avg_daily_sales_30d) > 90 THEN 'STOCK DORMANT'
        ELSE 'OK'
    END AS supply_status
FROM {{ ref('dim_products') }} p
LEFT JOIN sales_30d s ON p.PRODUCT_KEY = s.PRODUCT_KEY