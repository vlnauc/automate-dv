{{ config(schema='VLT', materialized='incremental', enabled=true, tags=['history', 'sats'])}}

SELECT
  stg.CUSTOMER_HASHDIFF,
	stg.CUSTOMER_PK,
	stg.CUSTOMER_NAME,
	stg.CUSTOMER_ADDRESS,
	stg.CUSTOMER_PHONE,
	stg.CUSTOMER_ACCBAL,
	stg.CUSTOMER_MKTSEGMENT,
	stg.CUSTOMER_COMMENT,
	stg.LOADDATE,
  stg.EFFECTIVE_FROM,
	stg.SOURCE
FROM (
SELECT
  b.CUSTOMER_HASHDIFF,
	b.CUSTOMER_PK,
	b.CUSTOMER_NAME,
	b.CUSTOMER_ADDRESS,
	b.CUSTOMER_PHONE,
	b.CUSTOMER_ACCBAL,
	b.CUSTOMER_MKTSEGMENT,
	b.CUSTOMER_COMMENT,
	b.LOADDATE,
  LEAD(b.LOADDATE, 1) OVER(PARTITION BY b.CUSTOMER_HASHDIFF ORDER BY b.LOADDATE) AS LATEST,
  b.EFFECTIVE_FROM,
	b.SOURCE
FROM

{% if is_incremental() %}
(
SELECT DISTINCT
  a.CUSTOMER_HASHDIFF,
	a.CUSTOMER_PK,
	a.CUSTOMER_NAME,
	a.CUSTOMER_ADDRESS,
	a.CUSTOMER_PHONE,
	a.CUSTOMER_ACCBAL,
	a.CUSTOMER_MKTSEGMENT,
	a.CUSTOMER_COMMENT,
	a.LOADDATE,
  a.EFFECTIVE_FROM,
	a.SOURCE
FROM {{ref('v_stg_tpch_data')}} AS a
LEFT JOIN {{this}} AS c ON a.CUSTOMER_HASHDIFF=c.CUSTOMER_HASHDIFF AND c.CUSTOMER_HASHDIFF IS NULL
) AS b)

{% else %}

{{ref('v_stg_tpch_data')}} AS b)

{% endif %}

AS stg

{% if is_incremental() %}

WHERE stg.CUSTOMER_HASHDIFF NOT IN (SELECT CUSTOMER_HASHDIFF FROM {{this}}) AND stg.LATEST IS NULL

{% else %}

WHERE stg.LATEST IS NULL

{% endif %}