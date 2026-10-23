-- 05_cohort_retention.sql
-- Monthly acquisition cohorts (month of first purchase) x months since first purchase.
-- retention_pct = % of the cohort that purchased again in month k (k >= 1); k = 0 is 100% by definition.
WITH base AS (
  SELECT user_id,
         date_trunc('month', first_purchase_at)::DATE AS cohort_month,
         date_diff('month', date_trunc('month', first_purchase_at), date_trunc('month', purchased_at)) AS month_k,
         gmv
  FROM purchases
),
size AS (SELECT cohort_month, COUNT(DISTINCT user_id) AS cohort_size FROM base GROUP BY 1)
SELECT b.cohort_month, s.cohort_size, b.month_k,
       COUNT(DISTINCT b.user_id)                                       AS active_buyers,
       ROUND(COUNT(DISTINCT b.user_id) * 100.0 / s.cohort_size, 3)     AS retention_pct,
       ROUND(SUM(b.gmv), 2)                                            AS gmv
FROM base b JOIN size s USING (cohort_month)
GROUP BY 1, 2, 3 ORDER BY 1, 3;
