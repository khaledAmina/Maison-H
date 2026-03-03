-- Si cette requête renvoie des lignes, le test échoue.
SELECT *
FROM {{ ref('fct_sales') }}
WHERE date_key > CURRENT_DATE()