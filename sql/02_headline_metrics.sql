-- 02_headline_metrics.sql
-- Whole-window headline metrics referenced in the README.
WITH u AS (
  SELECT user_id, COUNT(*) AS n_orders, SUM(gmv) AS ltv FROM purchases GROUP BY 1
)
SELECT
  (SELECT COUNT(*) FROM orders)                                       AS orders_placed,
  (SELECT COUNT(*) FROM purchases)                                    AS purchase_orders,
  COUNT(*)                                                            AS unique_buyers,
  ROUND(AVG((n_orders >= 2)::INT) * 100, 2)                           AS repeat_buyer_pct,
  ROUND(SUM(ltv), 2)                                                  AS total_gmv,
  ROUND(SUM(ltv) / SUM(n_orders), 2)                                  AS aov,
  ROUND(AVG(n_orders), 4)                                             AS orders_per_buyer,
  ROUND(SUM(ltv) FILTER (WHERE n_orders >= 2) / SUM(ltv) * 100, 2)    AS gmv_share_from_repeat_buyers,
  (SELECT ROUND(AVG(is_late::INT) * 100, 2) FROM purchases WHERE is_delivered)   AS late_delivery_pct,
  (SELECT ROUND(AVG(review_score), 3) FROM purchases WHERE review_score IS NOT NULL) AS avg_review_score
FROM u;
