## 1. Présentation du Projet

Ce projet consiste en la mise en place d'une plateforme de données (Modern Data Stack) pour la **Maison H**, une enseigne de luxe. L'objectif est de centraliser les ventes, les clients (CRM) et les données produits pour fournir des analyses fiables et sécurisées.

---

## 2. Architecture de Données (Stack Technique)

Le projet repose sur une architecture **Médaillon** au sein de **Snowflake**, orchestrée par **dbt**.

### A. Couche RAW (Bronze)

* **Rôle** : Réception des fichiers bruts (CSV pour les ventes/produits, JSON pour le CRM).
* **Gouvernance** : Mise en place de **Masking Policies** (Masquage dynamique) sur Snowflake pour protéger les emails et numéros de téléphone. Seul le rôle `DBT_TRANSFORMER` peut voir les données en clair pour les transformer.

### B. Couche STAGING (Silver - Préparation)

* **Modèles** : `stg_sales_transactions`, `stg_crm_clients`, `stg_products_catalog`, `stg_stores`, `stg_exchange_rates`.
* **Actions** : Renommage des colonnes, typage (Cast), et **Pseudonymisation**. Les emails sont transformés en Hash SHA-256 pour respecter le RGPD tout en permettant de suivre un client.

### C. Couche INTERMEDIATE (Silver - Logique Métier)

* **`int_sales_transactions`** : Nettoyage, déduplication et conversion monétaire.
* **`int_sales_quarantined`** : Isolation des lignes avec erreurs (dates futures, montants aberrants, devises inconnues).
* **Utilité** : Garantit que seules les données valides atteignent la couche finale.

### D. Couche MARTS (Gold - Analyse)

* **Structure** : Schéma en étoile (Star Schema).
* **Table de faits (`fct_sales`)** : Table centrale optimisée en mode **incrémental** pour réduire les coûts Snowflake.
* **Dimensions (`dim_clients`, `dim_products`, etc.)** : Tables de référence contenant tous les attributs descriptifs.

---

## 3. Qualité et Intégrité des Données

Pour garantir la fiabilité des rapports, dbt exécute des tests à chaque cycle de production :

| Test | Colonne concernée | Utilité métier |
| --- | --- | --- |
| `unique` | `transaction_id` | Évite de compter deux fois une vente (CA faussé). |
| `not_null` | `amount_eur` | Garantit que chaque vente a un montant convertible. |
| `relationships` | `client_key` | Vérifie que chaque client facturé existe dans le référentiel CRM. |
| `accepted_values` | `currency_code` | S'assure que seules les devises gérées par la finance sont traitées. |

---

## 4. Optimisation FinOps & Performance

* **Warehouses Auto-suspend** : Paramétré sur 60 secondes pour ne payer que la consommation réelle.
* **Matérialisation Incrémentale** : Utilisation de la stratégie `delete+insert` sur `fct_sales` pour ne traiter que les données du jour, économisant ainsi les crédits Snowflake.
* **Clustering** : Données triées par `date_key` pour accélérer les temps de réponse dans Power BI.

---

## 5. Guide d'Utilisation du Pipeline

Pour mettre à jour les données et vérifier la qualité, utilisez les commandes suivantes dans votre terminal dbt :

1. `dbt run` : Lance les transformations (Staging -> Intermediate -> Marts).
2. `dbt test` : Vérifie l'intégrité de toutes les données.
3. `dbt run --full-refresh --select fct_sales` : À utiliser en cas de modification majeure des règles de filtrage.

---

### 🛡️ Note sur la Conformité RGPD

Aucune donnée personnelle identifiable (PII) n'est stockée en clair dans la base `ANALYTICS_DB`. Le lien entre un achat et un client se fait exclusivement via une **clé technique anonymisée**.