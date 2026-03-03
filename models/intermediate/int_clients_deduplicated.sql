WITH stg_clients AS (
    SELECT * FROM {{ ref('stg_crm_clients') }}
),

scored AS (
    SELECT 
        *,
        
        SOUNDEX(last_name) AS name_phonetic,
        
        RANK() OVER (
            PARTITION BY email_hash, SOUNDEX(last_name) 
            ORDER BY updated_at DESC, created_at DESC
        ) AS ranking
    FROM stg_clients
)

SELECT 
    -- Génération de la client_key (Surrogate Key) pour la Gold
    MD5(CONCAT(email_hash, '|', name_phonetic)) AS client_key,
    client_id AS source_client_id,
    email_hash,
    phone_hash,
    signup_store,
    vip_status_source,
    created_at,
    updated_at,
    -- Flag anonyme si pas de client_id
    CASE WHEN client_id IS NULL THEN TRUE ELSE FALSE END AS is_anonymous
FROM scored
WHERE ranking = 1