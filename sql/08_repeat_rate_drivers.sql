-- 08_repeat_rate_drivers.sql
-- Deep dive: does the FIRST order experience predict whether a buyer ever comes back?
-- Uses first purchases from 2017-01..2018-02 so every buyer has >= 6 months to repurchase.
WITH u AS (
  SELECT user_id, COUNT(*) AS n_purch FROM purchases GROUP BY 1
),
f AS (
  SELECT p.*, (u.n_purch >= 2)::INT AS repeated,
         CASE WHEN NOT p.is_delivered THEN '0. not delivered'
              WHEN p.days_vs_estimate <= -7 THEN '1. >=7d early'
              WHEN p.days_vs_estimate <= 0  THEN '2. 0-6d early'
              WHEN p.days_vs_estimate <= 7  THEN '3. 1-7d late'
              ELSE '4. >7d late' END AS delivery_bucket
  FROM purchases p JOIN u USING (user_id)
  WHERE p.purchase_seq = 1 AND p.purchased_at < TIMESTAMP '2018-03-01'
)
SELECT 'review_score' AS driver, COALESCE(CAST(review_score AS VARCHAR),'no review') AS bucket,
       COUNT(*) AS first_orders, ROUND(AVG(repeated)*100, 2) AS repeat_pct FROM f GROUP BY 1,2
UNION ALL
SELECT 'delivery_vs_estimate', delivery_bucket, COUNT(*), ROUND(AVG(repeated)*100, 2) FROM f GROUP BY 1,2
UNION ALL
SELECT 'late_flag', CASE WHEN is_late THEN 'late' WHEN is_delivered THEN 'on time' ELSE 'not delivered' END,
       COUNT(*), ROUND(AVG(repeated)*100, 2) FROM f GROUP BY 1,2
UNION ALL
SELECT 'region', region, COUNT(*), ROUND(AVG(repeated)*100, 2) FROM f GROUP BY 1,2
UNION ALL
SELECT 'first_order_value', CASE WHEN gmv < 50 THEN '1. <50' WHEN gmv < 100 THEN '2. 50-100'
                                 WHEN gmv < 200 THEN '3. 100-200' ELSE '4. 200+' END,
       COUNT(*), ROUND(AVG(repeated)*100, 2) FROM f GROUP BY 1,2
ORDER BY 1, 2;
