-- 07_active_users.sql
-- Daily/weekly/monthly active buyers and stickiness ratios (purchase-based activity).
-- For each day: DAU = buyers that day; WAU = buyers in trailing 7 days; MAU = trailing 28 days.
WITH days AS (
  SELECT CAST(d AS DATE) AS day FROM range(DATE '2017-01-28', DATE '2018-09-01', INTERVAL 1 DAY) t(d)
),
p AS (SELECT DISTINCT user_id, CAST(purchased_at AS DATE) AS day FROM purchases)
SELECT d.day,
       COUNT(DISTINCT p.user_id) FILTER (WHERE p.day = d.day)                    AS dau,
       COUNT(DISTINCT p.user_id) FILTER (WHERE p.day > d.day - 7)                AS wau,
       COUNT(DISTINCT p.user_id)                                                 AS mau_28d
FROM days d
JOIN p ON p.day > d.day - 28 AND p.day <= d.day
GROUP BY 1 ORDER BY 1;
