-- 10_metric_movement_review_dip.sql
-- Root-cause the month-over-month movement in average review score.
-- Decomposes each month's avg review into: late share x late-score + on-time share x on-time score,
-- so we can see whether a dip is a MIX effect (more late orders) or a RATE effect (worse scores at equal lateness).
SELECT date_trunc('month', purchased_at)::DATE                            AS month,
       COUNT(*)                                                           AS delivered_reviewed_orders,
       ROUND(AVG(review_score), 3)                                        AS avg_review,
       ROUND(AVG(is_late::INT) * 100, 2)                                  AS late_pct,
       ROUND(AVG(review_score) FILTER (WHERE is_late), 3)                 AS avg_review_late,
       ROUND(AVG(review_score) FILTER (WHERE NOT is_late), 3)             AS avg_review_on_time,
       ROUND(AVG(delivery_days), 2)                                       AS avg_delivery_days,
       ROUND(AVG(date_diff('day', purchased_at, estimated_at)), 2)        AS avg_promised_days
FROM purchases
WHERE is_delivered AND review_score IS NOT NULL
GROUP BY 1 ORDER BY 1;
