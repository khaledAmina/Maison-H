WITH stg_sales AS (
    SELECT * FROM {{ ref('stg_sales_transactions') }}
),

-- On exclut d'abord ce qui est parti en quarantaine
filtered_sales AS (
    SELECT * FROM stg_sales
    WHERE transaction_date <= CURRENT_DATE 
      AND (amount_eur IS NOT NULL OR currency_code = 'EUR')
),

deduplicated AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY transaction_id 
            ORDER BY transaction_date DESC -- On garde la version la plus récente
        ) AS row_num
    FROM filtered_sales
)

SELECT 
    * EXCLUDE row_num 
FROM deduplicated 
WHERE row_num = 1