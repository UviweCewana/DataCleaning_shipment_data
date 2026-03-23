-----===========================================================================================-----
---- Data Cleaning
---- Table : `project-bb3551be-8ada-46bf-bfa.1.data`
----============================================================================================----
----Query 1
--- Removing Leading/Trailing Whitespace

----==============================================


SELECT 
  shipment_id,
  TRIM(origin_warehouse) AS origin_warehouse,
  TRIM(destination_city) AS destination_city,
  TRIM(destination_state) AS destination_state,
  TRIM(carrier) AS carrier

  FROM `project-bb3551be-8ada-46bf-bfa.1.data`


-----========================================================
----- Query 2: Standardize Text Casting

-----==========================================================

SELECT 
  shipment_id,
  INITCAP(TRIM(origin_warehouse)) AS origin_warehouse,
  INITCAP(TRIM(destination_city)) AS destination_city,
  UPPER(TRIM(destination_state)) AS destination_state,
  INITCAP(TRIM(carrier)) AS carrier

  FROM `project-bb3551be-8ada-46bf-bfa.1.data`

---============================================================
----Query 3 : Replace String 'NULL' and Handle true NULLS
----==========================================================

SELECT 
  shipment_id,
  CASE
    WHEN damage_reported = 'NULL' THEN NULL
    ELSE INITCAP(TRIM(damage_reported))
  END AS damage_reported,

  COALESCE(destination_city, 'Unkown') AS destination_city,
  COALESCE(delivery_date, 'Not Yet Delivered') AS delivery_date

  FROM `project-bb3551be-8ada-46bf-bfa.1.data`


-----=======================================================
-----Query 4: Duplicates removed
-----=======================================================
WITH ranked AS(
SELECT 
  *,
  ROW_NUMBER() OVER(
    PARTITION BY origin_warehouse, destination_city, ship_date, carrier, CAST(weight_kg AS STRING), CAST(freight_cost AS STRING)
    order by shipment_id
  ) AS row_num

  FROM `project-bb3551be-8ada-46bf-bfa.1.data`

)

SELECT * EXCEPT(row_num)
FROM ranked
WHERE row_num = 1


-----================================================
----- Query 5 : fixing negetive values and suspicious values
-----=================================================
SELECT
  shipment_id,
  CASE
    WHEN weight_kg <0 THEN ABS(weight_kg)
    WHEN weight_kg =0 THEN NULL
    ELSE weight_kg
  END AS weight_kg_cleaned

FROM `project-bb3551be-8ada-46bf-bfa.1.data`




-----===============================================================
---- Query 6 Validate Date Logic (DELIVERY AFTER SHIP DATE)
-----================================================================
SELECT
  shipment_id,
  ship_date,
  delivery_date,

DATE_DIFF(
  SAFE.PARSE_DATE('%Y-%m-%d',delivery_date),
  SAFE.PARSE_DATE('%Y-%m-%d',ship_date),
  DAY
) AS transit_days,

CASE
  WHEN SAFE.PARSE_DATE('%Y-%m-%d',delivery_date) < SAFE.PARSE_DATE('%Y-%m-%d',ship_date) THEN 'INVALID'
  WHEN SAFE.PARSE_DATE('%Y-%m-%d',delivery_date) = SAFE.PARSE_DATE('%Y-%m-%d',ship_date) THEN 'SAME DAY DELIVERY'
  ELSE 'VALID'
END AS data_quality_flag

FROM `project-bb3551be-8ada-46bf-bfa.1.data`


-------==============================================================
------ QUERY 7 : Detect & cap ouliers using percentiles (IQR)
------=================================================================

WITH stats AS(

  SELECT
    APPROX_QUANTILES(freight_cost, 100)[OFFSET(25)] AS q1,
    APPROX_QUANTILES(freight_cost, 100)[OFFSET(75)] AS q3
  FROM `project-bb3551be-8ada-46bf-bfa.1.data`

  WHERE freight_cost >0
),

bounds AS (
  SELECT
    q1 - 1.5 * (q3 - q1) AS lower_bound,
    q3 + 1.5 * (q3 - q1) AS upper_bound
  FROM stats
)

SELECT
  shipment_id,
  freight_cost AS original_cost,
  CASE
    WHEN freight_cost > (SELECT upper_bound from bounds) THEN (SELECT upper_bound FROM bounds)
    WHEN freight_cost < (SELECT lower_bound from bounds) THEN (SELECT lower_bound FROM bounds)
    ELSE freight_cost
  END AS cleaned_cost,


CASE 
  WHEN freight_cost > (SELECT upper_bound from bounds) OR 
  freight_cost < (SELECT lower_bound from bounds) THEN TRUE
  ELSE FALSE 

END AS was_outlier

FROM `project-bb3551be-8ada-46bf-bfa.1.data`


-----===========================================================
----- Full Query : Full Data Cleaning pipeline
------============================================================


WITH 
-- =====================================================================
-- STAGE 1: DATA CLEANING - Remove Leading/Trailing Whitespace
-- =====================================================================
stage1_trim AS (
  SELECT 
    shipment_id,
    TRIM(origin_warehouse) AS origin_warehouse,
    TRIM(destination_city) AS destination_city,
    TRIM(destination_state) AS destination_state,
    TRIM(carrier) AS carrier,
    damage_reported,
    delivery_date,
    ship_date,
    weight_kg,
    freight_cost
  FROM `project-bb3551be-8ada-46bf-bfa.1.data`
),

-- =====================================================================
-- STAGE 2: Standardize Text Casting (Proper Case & Upper Case)
-- =====================================================================
stage2_standardize AS (
  SELECT 
    shipment_id,
    INITCAP(origin_warehouse) AS origin_warehouse,
    INITCAP(destination_city) AS destination_city,
    UPPER(destination_state) AS destination_state,
    INITCAP(carrier) AS carrier,
    damage_reported,
    delivery_date,
    ship_date,
    weight_kg,
    freight_cost
  FROM stage1_trim
),

-- =====================================================================
-- STAGE 3: Replace String 'NULL' and Handle True NULLs
-- =====================================================================
stage3_null_handling AS (
  SELECT 
    shipment_id,
    origin_warehouse,
    destination_city,
    destination_state,
    carrier,
    -- Handle damage_reported: convert string 'NULL' to actual NULL
    CASE
      WHEN damage_reported = 'NULL' THEN NULL
      ELSE INITCAP(TRIM(damage_reported))
    END AS damage_reported,
    -- Handle destination_city: replace NULL with 'Unknown'
    COALESCE(destination_city, 'Unknown') AS destination_city_clean,
    -- Handle delivery_date: replace NULL with 'Not Yet Delivered'
    COALESCE(delivery_date, 'Not Yet Delivered') AS delivery_date_clean,
    ship_date,
    weight_kg,
    freight_cost
  FROM stage2_standardize
),

-- =====================================================================
-- STAGE 4: Remove Duplicates using ROW_NUMBER()
-- =====================================================================
stage4_dedupe AS (
  SELECT 
    shipment_id,
    origin_warehouse,
    destination_city_clean AS destination_city,
    destination_state,
    carrier,
    damage_reported,
    delivery_date_clean AS delivery_date,
    ship_date,
    weight_kg,
    freight_cost,
    ROW_NUMBER() OVER(
      PARTITION BY 
        origin_warehouse, 
        destination_city_clean, 
        ship_date, 
        carrier, 
        CAST(weight_kg AS STRING), 
        CAST(freight_cost AS STRING)
      ORDER BY shipment_id
    ) AS row_num
  FROM stage3_null_handling
),

stage4_dedupe_clean AS (
  SELECT 
    shipment_id,
    origin_warehouse,
    destination_city,
    destination_state,
    carrier,
    damage_reported,
    delivery_date,
    ship_date,
    weight_kg,
    freight_cost
  FROM stage4_dedupe
  WHERE row_num = 1
),

-- =====================================================================
-- STAGE 5: Fix Negative Values and Suspicious Values
-- =====================================================================
stage5_negative_fix AS (
  SELECT
    shipment_id,
    origin_warehouse,
    destination_city,
    destination_state,
    carrier,
    damage_reported,
    delivery_date,
    ship_date,
    -- Fix weight_kg: convert negatives to absolute, set zero to NULL
    CASE
      WHEN weight_kg < 0 THEN ABS(weight_kg)
      WHEN weight_kg = 0 THEN NULL
      ELSE weight_kg
    END AS weight_kg_cleaned,
    freight_cost
  FROM stage4_dedupe_clean
),

-- =====================================================================
-- STAGE 6: Validate Date Logic (Delivery AFTER Ship Date)
-- =====================================================================
stage6_date_validation AS (
  SELECT
    shipment_id,
    origin_warehouse,
    destination_city,
    destination_state,
    carrier,
    damage_reported,
    delivery_date,
    ship_date,
    weight_kg_cleaned AS weight_kg,
    freight_cost,
    -- Calculate transit days (only for valid dates)
    CASE
      WHEN SAFE.PARSE_DATE('%Y-%m-%d', delivery_date) IS NOT NULL 
       AND SAFE.PARSE_DATE('%Y-%m-%d', ship_date) IS NOT NULL
      THEN DATE_DIFF(
          SAFE.PARSE_DATE('%Y-%m-%d', delivery_date),
          SAFE.PARSE_DATE('%Y-%m-%d', ship_date),
          DAY
        )
      ELSE NULL
    END AS transit_days,
    -- Add data quality flag
    CASE
      WHEN SAFE.PARSE_DATE('%Y-%m-%d', delivery_date) IS NULL THEN 'NO_DELIVERY_DATE'
      WHEN SAFE.PARSE_DATE('%Y-%m-%d', ship_date) IS NULL THEN 'NO_SHIP_DATE'
      WHEN SAFE.PARSE_DATE('%Y-%m-%d', delivery_date) < SAFE.PARSE_DATE('%Y-%m-%d', ship_date) THEN 'INVALID'
      WHEN SAFE.PARSE_DATE('%Y-%m-%d', delivery_date) = SAFE.PARSE_DATE('%Y-%m-%d', ship_date) THEN 'SAME_DAY_DELIVERY'
      ELSE 'VALID'
    END AS data_quality_flag
  FROM stage5_negative_fix
),

-- =====================================================================
-- STAGE 7: Detect & Cap Outliers using Percentiles (IQR)
-- =====================================================================
stage7_outlier_stats AS (
  SELECT
    APPROX_QUANTILES(freight_cost, 100)[OFFSET(25)] AS q1,
    APPROX_QUANTILES(freight_cost, 100)[OFFSET(75)] AS q3
  FROM stage6_date_validation
  WHERE freight_cost > 0
),

stage7_bounds AS (
  SELECT
    q1 - 1.5 * (q3 - q1) AS lower_bound,
    q3 + 1.5 * (q3 - q1) AS upper_bound
  FROM stage7_outlier_stats
)

-- =====================================================================
-- FINAL OUTPUT: Cleaned Data with Outlier Handling
-- =====================================================================
SELECT
  shipment_id,
  origin_warehouse,
  destination_city,
  destination_state,
  carrier,
  damage_reported,
  delivery_date,
  ship_date,
  weight_kg,
  -- Original vs cleaned freight cost
  freight_cost AS original_freight_cost,
  CASE
    WHEN freight_cost > (SELECT upper_bound FROM stage7_bounds) 
         THEN (SELECT upper_bound FROM stage7_bounds)
    WHEN freight_cost < (SELECT lower_bound FROM stage7_bounds) 
         THEN (SELECT lower_bound FROM stage7_bounds)
    ELSE freight_cost
  END AS cleaned_freight_cost,
  -- Flag if it was an outlier
  CASE 
    WHEN freight_cost > (SELECT upper_bound FROM stage7_bounds) 
         OR freight_cost < (SELECT lower_bound FROM stage7_bounds) 
    THEN TRUE
    ELSE FALSE 
  END AS was_outlier,
  -- Additional fields from date validation
  transit_days,
  data_quality_flag
FROM stage6_date_validation
ORDER BY shipment_id;