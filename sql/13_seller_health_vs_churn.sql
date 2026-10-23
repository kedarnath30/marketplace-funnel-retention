-- 13_seller_health_vs_churn.sql
-- Does a seller's early service quality predict whether they keep selling?
-- Sellers with first sale Jan-2017..Feb-2018 and >= 5 orders in their first 90 days.
-- retained_m4_6 = seller made >= 1 sale in days 91-180 after their first sale.
WITH s AS (
  SELECT seller_id,
         MIN(seller_first_sale_at) AS first_at,
         COUNT(*) FILTER (WHERE purchased_at <  seller_first_sale_at + INTERVAL 90 DAY)  AS orders_90d,
         AVG(is_late::INT) FILTER (WHERE purchased_at < seller_first_sale_at + INTERVAL 90 DAY AND is_delivered) AS late_rate_90d,
         AVG(review_score) FILTER (WHERE purchased_at < seller_first_sale_at + INTERVAL 90 DAY) AS avg_review_90d,
         MAX((purchased_at >= seller_first_sale_at + INTERVAL 90 DAY
          AND purchased_at <  seller_first_sale_at + INTERVAL 180 DAY)::INT)                AS retained_m4_6
  FROM seller_orders GROUP BY 1
),
f AS (SELECT * FROM s WHERE first_at < TIMESTAMP '2018-03-01' AND orders_90d >= 5)
SELECT 'early_avg_review' AS driver,
       CASE WHEN avg_review_90d < 3.5 THEN '1. <3.5' WHEN avg_review_90d < 4.0 THEN '2. 3.5-4.0'
            WHEN avg_review_90d < 4.5 THEN '3. 4.0-4.5' ELSE '4. >=4.5' END AS bucket,
       COUNT(*) AS sellers, ROUND(AVG(retained_m4_6) * 100, 2) AS retained_pct
FROM f GROUP BY 1, 2
UNION ALL
SELECT 'early_late_rate',
       CASE WHEN late_rate_90d IS NULL THEN '0. no deliveries' WHEN late_rate_90d = 0 THEN '1. 0%'
            WHEN late_rate_90d <= 0.10 THEN '2. 0-10%' ELSE '3. >10%' END,
       COUNT(*), ROUND(AVG(retained_m4_6) * 100, 2) FROM f GROUP BY 1, 2
UNION ALL
SELECT 'early_volume',
       CASE WHEN orders_90d < 10 THEN '1. 5-9' WHEN orders_90d < 25 THEN '2. 10-24'
            WHEN orders_90d < 50 THEN '3. 25-49' ELSE '4. 50+' END,
       COUNT(*), ROUND(AVG(retained_m4_6) * 100, 2) FROM f GROUP BY 1, 2
UNION ALL
SELECT 'all', 'all', COUNT(*), ROUND(AVG(retained_m4_6) * 100, 2) FROM f
ORDER BY 1, 2;
