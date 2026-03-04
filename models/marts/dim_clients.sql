WITH base_clients AS (
    SELECT     client_key,
    email_hash,
    phone_hash,
    signup_store,
    vip_status_source,
    created_at,
    updated_at FROM {{ ref('int_clients_deduplicated') }}
),

-- On crée une ligne statique pour les clients anonymes
-- Pour resoudre le test relationships_fct_sales_client_key_client_key_ref_dim_clients
anonymous_row AS (
    SELECT
        'ANONYMOUS' AS client_key,
        NULL AS email_hash,
        NULL AS phone_hash,
        NULL AS signup_store,
        'NONE' AS vip_status_source,
        CURRENT_TIMESTAMP() AS created_at,
        CURRENT_TIMESTAMP() AS updated_at
)

SELECT * FROM base_clients
UNION ALL
SELECT * FROM anonymous_row