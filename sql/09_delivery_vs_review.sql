-- 09_delivery_vs_review.sql
-- Review score and 1-star share by delivery delay vs promised date (delivered orders).
SELECT CASE WHEN days_vs_estimate <= -14 THEN 'a. >=14d early'
            WHEN days_vs_estimate <= -7  THEN 'b. 7-13d early'
            WHEN days_vs_estimate <= 0   THEN 'c. 0-6d early'
            WHEN days_vs_estimate <= 3   THEN 'd. 1-3d late'
            WHEN days_vs_estimate <= 7   THEN 'e. 4-7d late'
            WHEN days_vs_estimate <= 14  THEN 'f. 8-14d late'
            ELSE 'g. >14d late' END                          AS delay_bucket,
       COUNT(*)                                             AS orders,
       ROUND(AVG(review_score), 3)                          AS avg_review,
       ROUND(AVG((review_score = 1)::INT) * 100, 2)         AS one_star_pct,
       ROUND(AVG((review_score >= 4)::INT) * 100, 2)        AS positive_pct
FROM purchases
WHERE is_delivered AND review_score IS NOT NULL
GROUP BY 1 ORDER BY 1;
