{% macro convert_to_eur(amount_column, rate_column) %}
    -- Si le taux est trouvé, on multiplie, sinon on retourne NULL 
    CAST(
        CASE 
            WHEN {{ amount_column }} IS NULL THEN NULL
            WHEN {{ rate_column }} IS NULL THEN NULL 
            ELSE {{ amount_column }} * {{ rate_column }}
        END 
    AS DECIMAL(12,2))
{% endmacro %}