-- 11_time_to_second_purchase.sql
-- Distribution of days between a buyer's 1st and 2nd purchase (buyers with >= 2 purchases).
WITH s AS (
  SELECT user_id,
         date_diff('day', MIN(purchased_at) FILTER (WHERE purchase_seq = 1),
                          MIN(purchased_at) FILTER (WHERE purchase_seq = 2)) AS days_to_2nd
  FROM purchases GROUP BY 1 HAVING COUNT(*) >= 2
)
SELECT CASE WHEN days_to_2nd = 0 THEN 'a. same day'
            WHEN days_to_2nd <= 7 THEN 'b. 1-7d'
            WHEN days_to_2nd <= 30 THEN 'c. 8-30d'
            WHEN days_to_2nd <= 90 THEN 'd. 31-90d'
            WHEN days_to_2nd <= 180 THEN 'e. 91-180d'
            ELSE 'f. 180d+' END AS bucket,
       COUNT(*) AS buyers,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct,
       ROUND(MEDIAN(days_to_2nd), 1) AS median_days_in_bucket
FROM s GROUP BY 1 ORDER BY 1;
