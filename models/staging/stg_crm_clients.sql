WITH source AS (
    SELECT * FROM {{ source('maison_h_raw', 'src_crm_clients') }}
),

cleaned AS (
    SELECT
        client_id,
        first_name,
        last_name,
        -- Pseudonymisation SHA-256
        SHA2_HEX(CONCAT(LOWER(TRIM(email)), 'MAISON_H_SALT_2026')) AS email_hash,
        SHA2_HEX(CONCAT(TRIM(phone), 'MAISON_H_SALT_2026')) AS phone_hash,
        signup_store,
        UPPER(vip_status) AS vip_status_source, -- Normalisation
        created_at,
        updated_at
    FROM source
)

SELECT * FROM cleaned