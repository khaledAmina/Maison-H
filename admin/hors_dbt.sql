-- ============================================================
--  SNOWFLAKE SETUP SCRIPT — VERSION FINALE
-- ============================================================


-- ============================================================
--  1. BASES DE DONNÉES
-- ============================================================

CREATE OR REPLACE DATABASE RAW_DB;        -- Données brutes
CREATE OR REPLACE DATABASE ANALYTICS_DB;  -- Transformations dbt


-- ============================================================
--  2. WAREHOUSE (FinOps — auto-suspend agressif)
-- ============================================================

CREATE WAREHOUSE IF NOT EXISTS DBT_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE;


-- ============================================================
--  3. SÉCURITÉ & RBAC
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- Création du rôle
CREATE ROLE IF NOT EXISTS DBT_TRANSFORMER;

-- ── Warehouse ──────────────────────────────────────────────
GRANT USAGE ON WAREHOUSE DBT_WH TO ROLE DBT_TRANSFORMER;

-- ── RAW_DB : accès lecture seule ───────────────────────────

GRANT USAGE  ON DATABASE RAW_DB                        TO ROLE DBT_TRANSFORMER;
GRANT USAGE  ON SCHEMA   RAW_DB.PUBLIC                 TO ROLE DBT_TRANSFORMER;
GRANT SELECT ON ALL TABLES IN SCHEMA RAW_DB.PUBLIC     TO ROLE DBT_TRANSFORMER;

-- FUTURE GRANTS : couvre les tables créées après ce script
GRANT SELECT ON FUTURE TABLES IN SCHEMA RAW_DB.PUBLIC  TO ROLE DBT_TRANSFORMER;

-- ── ANALYTICS_DB : droits de transformation ────────────────

GRANT USAGE         ON DATABASE ANALYTICS_DB           TO ROLE DBT_TRANSFORMER;
GRANT CREATE SCHEMA ON DATABASE ANALYTICS_DB           TO ROLE DBT_TRANSFORMER;

-- FUTURE GRANTS sur les schémas et tables créés par dbt
GRANT ALL ON FUTURE SCHEMAS IN DATABASE ANALYTICS_DB   TO ROLE DBT_TRANSFORMER;
GRANT ALL ON FUTURE TABLES  IN DATABASE ANALYTICS_DB   TO ROLE DBT_TRANSFORMER;

-- ── Attribution du rôle à l'utilisateur ────────────────────
SELECT CURRENT_USER();
GRANT ROLE DBT_TRANSFORMER TO USER ******** ;


-- ============================================================
--  4. POLITIQUES DE MASQUAGE RGPD (zone RAW)
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RAW_DB;
CREATE SCHEMA IF NOT EXISTS SECURITY;

-- Politique Email : masque tout sauf le domaine
CREATE OR REPLACE MASKING POLICY RAW_DB.SECURITY.email_mask
    AS (val STRING) RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DBT_TRANSFORMER', 'ACCOUNTADMIN') THEN val
        ELSE '**********' || REGEXP_SUBSTR(val, '@.*')
    END;

-- Politique Téléphone : masque tous les chiffres sauf les 2 derniers
CREATE OR REPLACE MASKING POLICY RAW_DB.SECURITY.phone_mask
    AS (val STRING) RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DBT_TRANSFORMER', 'ACCOUNTADMIN') THEN val
        ELSE '********' || RIGHT(val, 2)
    END;


-- ============================================================
--  5. TABLES SOURCE (RAW_DB)
-- ============================================================

USE ROLE   DBT_TRANSFORMER;
USE DATABASE RAW_DB;
USE SCHEMA   PUBLIC;

CREATE OR REPLACE TABLE RAW_DB.PUBLIC.src_sales_transactions (
    trans_id    VARCHAR,
    client_id   VARCHAR,
    store_id    VARCHAR,
    product_ref VARCHAR,
    quantity    INT,
    amount      DECIMAL(12,2),
    currency    VARCHAR(3),
    trans_date  DATE,
    channel     VARCHAR
);

CREATE OR REPLACE TABLE RAW_DB.PUBLIC.src_crm_clients (
    client_id    VARCHAR,
    first_name   VARCHAR,
    last_name    VARCHAR,
    email        VARCHAR,
    phone        VARCHAR,
    signup_store VARCHAR,
    vip_status   VARCHAR,
    created_at   TIMESTAMP,
    updated_at   TIMESTAMP
);

-- Application des politiques de masquage

ALTER TABLE src_crm_clients MODIFY COLUMN email SET MASKING POLICY RAW_DB.SECURITY.email_mask;
ALTER TABLE src_crm_clients MODIFY COLUMN phone SET MASKING POLICY RAW_DB.SECURITY.phone_mask;

CREATE OR REPLACE TABLE RAW_DB.PUBLIC.src_products_catalog (
    sku          VARCHAR,
    product_name VARCHAR,
    metier       VARCHAR,
    category     VARCHAR,
    collection   VARCHAR,
    price_eur    DECIMAL(10,2)
);

CREATE OR REPLACE TABLE RAW_DB.PUBLIC.src_stores (
    store_id   VARCHAR,
    store_name VARCHAR,
    city       VARCHAR,
    country    VARCHAR,
    region     VARCHAR,
    channel    VARCHAR
);

CREATE OR REPLACE TABLE RAW_DB.PUBLIC.src_exchange_rates (
    currency_code VARCHAR(3),
    rate_to_eur   DECIMAL(10,6),
    valid_from    DATE,
    valid_to      DATE
);


-- ============================================================
--  6. FILE FORMATS
-- ============================================================

-- CSV délimiteur ';'
CREATE OR REPLACE FILE FORMAT RAW_DB.PUBLIC.CSV_FORMAT_1
    TYPE              = 'CSV'
    FIELD_DELIMITER   = ';'
    SKIP_HEADER       = 1
    NULL_IF           = ('NULL', '')
    EMPTY_FIELD_AS_NULL = TRUE;

-- CSV délimiteur ','
CREATE OR REPLACE FILE FORMAT RAW_DB.PUBLIC.CSV_FORMAT_2
    TYPE              = 'CSV'
    FIELD_DELIMITER   = ','
    SKIP_HEADER       = 1
    NULL_IF           = ('NULL', '')
    EMPTY_FIELD_AS_NULL = TRUE;

-- JSON
CREATE OR REPLACE FILE FORMAT RAW_DB.PUBLIC.json_FORMAT
    TYPE               = 'JSON'
    STRIP_OUTER_ARRAY  = TRUE;  -- Supprime les crochets [ ]


-- ============================================================
--  7. ANALYSE (PREVIEW DES FICHIERS STAGE)
-- ============================================================

SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
FROM @RAW_DB.PUBLIC.MY_STAGE/sales_transactions_raw.csv
(FILE_FORMAT => 'RAW_DB.PUBLIC.CSV_FORMAT_1');

SELECT $1, $2, $3, $4, $5, $6
FROM @RAW_DB.PUBLIC.MY_STAGE/ref_products_catalog.csv
(FILE_FORMAT => 'RAW_DB.PUBLIC.CSV_FORMAT_2');

SELECT $1, $2, $3, $4, $5, $6
FROM @RAW_DB.PUBLIC.MY_STAGE/ref_stores.csv
(FILE_FORMAT => 'RAW_DB.PUBLIC.CSV_FORMAT_2');

SELECT $1, $2, $3
FROM @RAW_DB.PUBLIC.MY_STAGE/seed_exchange_rates.csv
(FILE_FORMAT => 'RAW_DB.PUBLIC.CSV_FORMAT_2');

SELECT
    $1:client_id::VARCHAR,
    $1:first_name::VARCHAR,
    $1:last_name::VARCHAR,
    $1:email::VARCHAR,
    $1:phone::VARCHAR,
    $1:signup_store::VARCHAR,
    $1:vip_status::VARCHAR,
    $1:created_at::TIMESTAMP,
    $1:updated_at::TIMESTAMP
FROM @RAW_DB.PUBLIC.MY_STAGE/crm_clients_export.json
(FILE_FORMAT => 'RAW_DB.PUBLIC.json_FORMAT');


-- ============================================================
--  8. CHARGEMENT DES DONNÉES (COPY INTO)
-- ============================================================

COPY INTO src_sales_transactions
FROM @MY_STAGE/sales_transactions_raw.csv
FILE_FORMAT = (FORMAT_NAME = 'RAW_DB.PUBLIC.CSV_FORMAT_1')
ON_ERROR = 'CONTINUE';

COPY INTO src_products_catalog
FROM @MY_STAGE/ref_products_catalog.csv
FILE_FORMAT = (FORMAT_NAME = 'RAW_DB.PUBLIC.CSV_FORMAT_2')
ON_ERROR = 'CONTINUE';

COPY INTO src_stores
FROM @MY_STAGE/ref_stores.csv
FILE_FORMAT = (FORMAT_NAME = 'RAW_DB.PUBLIC.CSV_FORMAT_2')
ON_ERROR = 'CONTINUE';

COPY INTO src_exchange_rates
FROM @MY_STAGE/seed_exchange_rates.csv
FILE_FORMAT = (FORMAT_NAME = 'RAW_DB.PUBLIC.CSV_FORMAT_2')
ON_ERROR = 'CONTINUE';

COPY INTO RAW_DB.PUBLIC.src_crm_clients
FROM (
    SELECT
        $1:client_id::VARCHAR,
        $1:first_name::VARCHAR,
        $1:last_name::VARCHAR,
        $1:email::VARCHAR,
        $1:phone::VARCHAR,
        $1:signup_store::VARCHAR,
        $1:vip_status::VARCHAR,
        $1:created_at::TIMESTAMP,
        $1:updated_at::TIMESTAMP
    FROM @RAW_DB.PUBLIC.MY_STAGE/crm_clients_export.json
)
FILE_FORMAT = (FORMAT_NAME = 'RAW_DB.PUBLIC.json_FORMAT')
ON_ERROR = 'CONTINUE';


-- ============================================================
--  9. VÉRIFICATION DES DONNÉES CHARGÉES
-- ============================================================

SELECT TRANS_ID,COUNT(*) FROM src_sales_transactions
 group by TRANS_ID
 having COUNT(*)>1;

 SELECT * FROM src_sales_transactions
 where TRANS_ID='TRX-00114873';
SELECT * FROM src_crm_clients;
SELECT * FROM src_products_catalog;
SELECT * FROM src_stores;
SELECT * FROM src_exchange_rates;


-- ============================================================
--  10. VÉRIFICATION DES MODÈLES dbt (ANALYTICS_DB)
-- ============================================================

USE ROLE     DBT_TRANSFORMER;
USE DATABASE ANALYTICS_DB;
USE SCHEMA   DBT_KAMINA;

SELECT * FROM FCT_SALES       WHERE TRANSACTION_ID = 'TRX-00114873';
SELECT * FROM DIM_CLIENTS     WHERE CLIENT_KEY     = 'f18cd59ac45cafb6910dca6526fced54';
SELECT * FROM DIM_PRODUCTS    WHERE PRODUCT_KEY    = 'H-MAR-0016';
SELECT * FROM DIM_STORES      WHERE STORE_KEY      = 'ST-MIL-001';
SELECT * FROM DIM_DATE        WHERE DATE_KEY       = '2024-01-01 00:00:00.000';
SELECT * FROM DIM_CLIENTS     WHERE CLIENT_KEY     = 'ANONYMOUS';

-- Chiffre d'affaires par Magasin, Métier et Mois
SELECT
    SALES_MONTH,
    STORE_NAME,
    METIER,
    TURNOVER_GROSS,       -- CA Brut
    TURNOVER_NET,         -- CA Net
    nb_transactions,
    nb_unique_customers,
    average_basket        -- Panier moyen (CA Net / Transactions)
FROM MART_TURNOVER_ANALYSIS;

-- Golden Record : segmentation client
SELECT
    CLIENT_KEY,
    EMAIL_HASH,
    VIP_STATUS_SOURCE,
    ltv,
    last_purchase_date,
    total_transactions,
    stores_visited,
    favorite_metier,
    SEGMENTATION_LABEL    -- Variable dbt paramétrable
FROM MART_VIC_SEGMENTATION;

SELECT
    SEGMENTATION_LABEL,
    COUNT(*)  AS NB_CLIENTS,
    SUM(LTV)  AS TOTAL_REVENUE
FROM ANALYTICS_DB.DBT_KAMINA.MART_VIC_SEGMENTATION
GROUP BY 1
ORDER BY NB_CLIENTS DESC;

-- Suivi supply chain
SELECT
    PRODUCT_KEY,
    PRODUCT_NAME,
    METIER,
    CATEGORY,
    100 AS current_stock,   -- Stock fixe pour l'exercice
    avg_daily_sales_30d,
    stock_coverage_days,
    supply_status
FROM MART_SUPPLY_MONITORING;