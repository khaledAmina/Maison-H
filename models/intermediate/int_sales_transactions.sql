WITH stg_sales AS (
    SELECT * FROM {{ ref('stg_sales_transactions') }}
),

-- On exclut les données parties en quarantaine pour garder une base saine
valid_sales AS (
    SELECT s.* FROM stg_sales s
    LEFT JOIN {{ ref('int_sales_quarantined') }} q ON s.transaction_id = q.transaction_id
    WHERE q.transaction_id IS NULL
),

deduplicated AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY transaction_id 
            ORDER BY transaction_date DESC -- On garde la version la plus récente
        ) AS row_num
    FROM valid_sales
)

SELECT * EXCLUDE row_num FROM deduplicated WHERE row_num = 1