WITH stg_clients AS (
    SELECT * FROM {{ ref('stg_crm_clients') }}
),

scored_clients AS (
    SELECT 
        *,
        -- On crée une clé de regroupement basée sur le Soundex du nom
        -- Cela permet de matcher "Martin" et "Martine" ou des erreurs de frappe
        SOUNDEX(last_name) AS name_phonetic,
        
        -- On numérote les clients par groupe (Email + Nom Phonétique)
        -- On garde le plus récent selon la date de mise à jour
        ROW_NUMBER() OVER (
            PARTITION BY email_hash, SOUNDEX(last_name) 
            ORDER BY updated_at DESC, created_at DESC
        ) AS row_num
    FROM stg_clients
)

SELECT 
    -- Génération d'une clé unique (client_key) pour le Golden Record
    MD5(CONCAT(email_hash, '|', phone_hash)) AS client_key,
    client_id AS source_client_id,
    email_hash,
    phone_hash,
    signup_store,
    vip_status_source,
    created_at,
    updated_at,
    CASE 
        WHEN client_id IS NULL THEN TRUE 
        ELSE FALSE 
    END AS is_anonymous
FROM scored_clients
WHERE row_num = 1 -- On ne garde que l'enregistrement "Maître"