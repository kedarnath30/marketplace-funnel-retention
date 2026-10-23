-- 01_north_star_monthly.sql
-- Monthly KPI table: north star (monthly active buyers) + its drivers.
SELECT date_trunc('month', purchased_at)::DATE                         AS month,
       COUNT(DISTINCT user_id)                                         AS active_buyers,
       COUNT(DISTINCT user_id) FILTER (WHERE date_trunc('month', first_purchase_at) = date_trunc('month', purchased_at)) AS new_buyers,
       COUNT(DISTINCT user_id) FILTER (WHERE date_trunc('month', first_purchase_at) < date_trunc('month', purchased_at))  AS returning_buyers,
       COUNT(*)                                                        AS orders,
       ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT user_id), 3)              AS orders_per_buyer,
       ROUND(SUM(gmv), 2)                                              AS gmv,
       ROUND(AVG(gmv), 2)                                              AS aov,
       ROUND(AVG(is_late::INT) FILTER (WHERE is_delivered) * 100, 2)  AS late_delivery_pct,
       ROUND(AVG(review_score), 3)                                     AS avg_review_score
FROM purchases
GROUP BY 1 ORDER BY 1;
