# 💎 Plateforme de Données - Maison H (Modern Data Stack)

## 1. Présentation du Projet

Ce projet consiste en la mise en place d'une plateforme de données pour la **Maison H**, une enseigne de luxe. L'objectif est de centraliser les ventes, les clients (CRM) et les données produits pour fournir des analyses fiables, segmentées et sécurisées.

---

## 2. Architecture de Données (Stack Technique)

Le projet repose sur une architecture **Médaillon** au sein de **Snowflake**, orchestrée par **dbt**.

### A. Couche RAW (Bronze)

* **Rôle** : Réception des fichiers bruts (CSV pour les ventes/produits, JSON pour le CRM).
* **Gouvernance** : Mise en place de **Masking Policies** sur Snowflake. Seul le rôle `DBT_TRANSFORMER` accède aux données PII en clair pour la transformation.

### B. Couche STAGING & INTERMEDIATE (Silver)

* **Nettoyage & Typage** : Cast des dates et montants, renommage normalisé.
* **Pseudonymisation** : Les emails clients sont transformés en **Hash SHA-256** pour la conformité RGPD.
* **Qualité (Quarantaine)** : Isolation des données aberrantes (dates futures, devises inconnues) dans `int_sales_quarantined`.

### C. Couche MARTS (Gold - Analyse)

Cette couche est le point d'entrée pour Power BI. Elle s'appuie sur une modélisation hybride :

#### 🏗️ Modélisation en Étoile (En cours)

Le socle de performance repose sur un **Star Schema** :

* **Fait** : `fct_sales` (Table centrale, matérialisation **incrémentale**, clusterisée par `date_key`).
* **Dimensions** : `dim_clients`, `dim_products`, `dim_stores`.

#### 📊 Tables de Restitution Métiers

Construites sur le schéma en étoile pour simplifier l'accès aux KPIs :

1. **`mart_turnover_analysis`** :
* Analyse du CA (Brut vs Net), Panier Moyen et volumes de transactions.
* Granularité : Magasin / Métier / Mois.


2. **`mart_vic_segmentation`** :
* Calcul de la **Lifetime Value (LTV)** et segmentation dynamique via variables dbt (Prospect, Client, Top, V.I.C.).
* Identification du **Métier de prédilection** et suivi de la rétention.


3. **`mart_supply_monitoring`** (Nouveau) :
* Pilotage de la Supply Chain : **Stock Coverage** (couverture sur 30j) et Taux de rotation.
* Alertes automatiques : Flag sur stock critique (<7j) ou dormant (>90j).



## 3. Qualité et Intégrité des Données

| Test | Cible | Utilité métier |
| --- | --- | --- |
| `unique` | `transaction_id` | Évite le double comptage du CA. |
| `not_null` | `amount_eur` | Garantit la complétude financière. |
| `accepted_values` | `segment` | Valide la logique de segmentation client (Prospect -> VIC). |
| `relationships` | `client_key` | Vérifie que chaque vente est rattachée à un client existant. |

---

## 4. Optimisation FinOps & Performance

* **Clusterisation** : Les tables de faits sont triées par `date_key` pour accélérer les visuels Power BI.
* **Incrémentalité** : Utilisation de la stratégie `merge` (ou `delete+insert`) pour ne traiter que les nouvelles transactions quotidiennes.
* **Auto-suspend** : Entrepôts Snowflake configurés pour s'éteindre après 60s d'inactivité.

---

## 5. Guide d'Utilisation

1. **Installation** : `dbt deps`
2. **Exécution standard** : `dbt run`
3. **Tests de qualité** : `dbt test`
4. **Rafraîchissement total** : `dbt run --full-refresh --select fct_sales` (uniquement si modification de la logique historique).

---

### 🛡️ Note sur la Conformité RGPD

Aucune donnée personnelle identifiable (PII) n'est stockée en clair dans la base finale. Le lien entre un achat et un client se fait exclusivement via une **clé technique anonymisée**.