SELECT
    date_key,
    SUM(amount_eur) as total_net_amount
FROM {{ ref('fct_sales') }}
WHERE is_return = FALSE
GROUP BY 1
HAVING total_net_amount < 0