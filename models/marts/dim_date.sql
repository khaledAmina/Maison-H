WITH date_spine AS (
    -- Génération d'une séquence de dates de 2024 à 2026
    SELECT 
        DATEADD(day, seq4(), '2024-01-01') AS date_day
    FROM TABLE(GENERATOR(ROWCOUNT => 1095)) 
)

SELECT
    date_day AS date_key, -- Clé primaire
    EXTRACT(YEAR FROM date_day) AS year,
    EXTRACT(QUARTER FROM date_day) AS quarter,
    EXTRACT(MONTH FROM date_day) AS month,
    TO_CHAR(date_day, 'MMMM') AS month_name,
    EXTRACT(WEEK FROM date_day) AS week_of_year,
    CASE 
        WHEN EXTRACT(DAYOFWEEK FROM date_day) IN (0, 6) THEN TRUE 
        ELSE FALSE 
    END AS is_weekend,
    -- Année fiscale (Maison H peut avoir un décalage, par défaut = année civile)
    EXTRACT(YEAR FROM date_day) AS fiscal_year 
FROM date_spine