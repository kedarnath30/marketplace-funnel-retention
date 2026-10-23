-- 06_cohort_ltv.sql
-- LTV-style cumulative GMV per acquired buyer, by cohort and months since first purchase.
-- Only month_k values that are fully observed (cohort_month + k <= 2018-08) are emitted.
WITH base AS (
  SELECT date_trunc('month', first_purchase_at)::DATE AS cohort_month,
         date_diff('month', date_trunc('month', first_purchase_at), date_trunc('month', purchased_at)) AS month_k,
         user_id, gmv
  FROM purchases
),
size AS (SELECT cohort_month, COUNT(DISTINCT user_id) AS cohort_size FROM base GROUP BY 1),
grid AS (
  SELECT s.cohort_month, s.cohort_size, k.month_k
  FROM size s, range(0, 20) k(month_k)
  WHERE s.cohort_month + INTERVAL (k.month_k) MONTH <= DATE '2018-08-01'
),
m AS (SELECT cohort_month, month_k, SUM(gmv) AS gmv FROM base GROUP BY 1,2)
SELECT g.cohort_month, g.cohort_size, g.month_k,
       ROUND(SUM(COALESCE(m.gmv,0)) OVER (PARTITION BY g.cohort_month ORDER BY g.month_k) / g.cohort_size, 2) AS cum_gmv_per_buyer
FROM grid g LEFT JOIN m USING (cohort_month, month_k)
ORDER BY 1, 3;
