-- 03_funnel_overall.sql
-- Order-to-loyalty funnel. Stages 1-6 are order-level (all orders placed in window);
-- stage 7 is buyer-level: share of first orders whose buyer came back for a 2nd purchase.
WITH f AS (
  SELECT COUNT(*)                                                         AS placed,
         COUNT(*) FILTER (WHERE approved_at IS NOT NULL)                   AS approved,
         COUNT(*) FILTER (WHERE shipped_at  IS NOT NULL)                   AS shipped,
         COUNT(*) FILTER (WHERE is_delivered)                              AS delivered,
         COUNT(*) FILTER (WHERE is_delivered AND NOT is_late)              AS delivered_on_time,
         COUNT(*) FILTER (WHERE is_delivered AND NOT is_late AND review_score >= 4) AS on_time_and_positive_review
  FROM orders
)
SELECT stage_order, stage, n,
       ROUND(n * 100.0 / FIRST_VALUE(n) OVER (ORDER BY stage_order), 2) AS pct_of_placed,
       ROUND(n * 100.0 / LAG(n) OVER (ORDER BY stage_order), 2)         AS step_conversion_pct,
       ROUND(100 - n * 100.0 / LAG(n) OVER (ORDER BY stage_order), 2)   AS step_dropoff_pct
FROM (
  SELECT 1 AS stage_order, '1. Order placed' AS stage, placed AS n FROM f UNION ALL
  SELECT 2, '2. Payment approved', approved FROM f UNION ALL
  SELECT 3, '3. Handed to carrier', shipped FROM f UNION ALL
  SELECT 4, '4. Delivered', delivered FROM f UNION ALL
  SELECT 5, '5. Delivered on time', delivered_on_time FROM f UNION ALL
  SELECT 6, '6. On time + review >= 4', on_time_and_positive_review FROM f
) ORDER BY stage_order;
