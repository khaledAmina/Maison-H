SELECT 
    client_key,
    email_hash,
    phone_hash,
    signup_store,
    vip_status_source,
    created_at,
    updated_at
FROM {{ ref('int_clients_deduplicated') }}