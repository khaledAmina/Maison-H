WITH stg_sales AS (

    SELECT * FROM {{ ref('stg_sales_transactions') }}

)



SELECT

    *,

    CASE

        WHEN transaction_date > CURRENT_DATE THEN 'Date dans le futur'

        WHEN amount_eur IS NULL AND currency_code != 'EUR' THEN 'Devise inconnue ou taux manquant'

        WHEN quantity <= 0 AND is_return = FALSE THEN 'Quantité ou montant aberrant'

        ELSE 'Anomalie technique'

    END AS rejection_reason

FROM stg_sales

WHERE

    transaction_date > CURRENT_DATE

    OR (amount_eur IS NULL AND currency_code != 'EUR')

    OR (quantity <= 0 AND is_return = FALSE)