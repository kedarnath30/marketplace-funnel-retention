-- 14_marketplace_liquidity.sql
-- Two-sided health by month: active buyers, active sellers, buyers per seller,
-- and seller concentration (share of GMV from the top 10% of sellers that month).
WITH m AS (
  SELECT date_trunc('month', purchased_at)::DATE AS month, seller_id, SUM(seller_item_revenue) AS rev
  FROM seller_orders GROUP BY 1, 2
),
r AS (
  SELECT *, PERCENT_RANK() OVER (PARTITION BY month ORDER BY rev DESC) AS pr FROM m
),
b AS (SELECT date_trunc('month', purchased_at)::DATE AS month, COUNT(DISTINCT user_id) AS active_buyers FROM purchases GROUP BY 1)
SELECT r.month, b.active_buyers,
       COUNT(*)                                                 AS active_sellers,
       ROUND(b.active_buyers * 1.0 / COUNT(*), 2)               AS buyers_per_seller,
       ROUND(SUM(rev) FILTER (WHERE pr < 0.10) / SUM(rev) * 100, 2) AS top10pct_seller_gmv_share
FROM r JOIN b USING (month)
GROUP BY r.month, b.active_buyers ORDER BY 1;
