-- 12_seller_retention.sql
-- Supply-side retention: monthly seller cohorts (month of first sale) x months since first sale.
-- A seller is "active" in a month if they made >= 1 sale (purchase order) that month.
WITH base AS (
  SELECT DISTINCT seller_id,
         date_trunc('month', seller_first_sale_at)::DATE AS cohort_month,
         date_diff('month', date_trunc('month', seller_first_sale_at), date_trunc('month', purchased_at)) AS month_k
  FROM seller_orders
),
size AS (SELECT cohort_month, COUNT(DISTINCT seller_id) AS cohort_size FROM base GROUP BY 1)
SELECT b.cohort_month, s.cohort_size, b.month_k,
       COUNT(DISTINCT b.seller_id)                                   AS active_sellers,
       ROUND(COUNT(DISTINCT b.seller_id) * 100.0 / s.cohort_size, 2) AS retention_pct
FROM base b JOIN size s USING (cohort_month)
GROUP BY 1, 2, 3 ORDER BY 1, 3;
