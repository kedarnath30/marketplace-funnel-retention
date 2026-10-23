-- 04_funnel_segmented.sql
-- Same funnel, segmented by customer region, primary payment type and top-10 category.
-- repurchase_pct = share of distinct buyers in the segment with >= 2 purchases (by first-order segment).
WITH seg AS (
  SELECT 'region' AS dimension, region AS segment, * FROM orders
  UNION ALL SELECT 'payment_type', COALESCE(payment_type,'unknown'), * FROM orders
  UNION ALL SELECT 'category', main_category, * FROM orders
    WHERE main_category IN (SELECT main_category FROM orders WHERE main_category IS NOT NULL
                            GROUP BY 1 ORDER BY COUNT(*) DESC LIMIT 10)
),
firsts AS (
  SELECT *, COUNT(*) OVER (PARTITION BY user_id) AS n_purch
  FROM purchases QUALIFY purchase_seq = 1
),
rep AS (
  SELECT 'region' AS dimension, region AS segment, AVG((n_purch>=2)::INT) AS r FROM firsts GROUP BY 1,2
  UNION ALL SELECT 'payment_type', payment_type, AVG((n_purch>=2)::INT) FROM firsts GROUP BY 1,2
  UNION ALL SELECT 'category', main_category, AVG((n_purch>=2)::INT) FROM firsts GROUP BY 1,2
)
SELECT s.dimension, s.segment,
       COUNT(*)                                                                      AS placed,
       ROUND(AVG((approved_at IS NOT NULL)::INT) * 100, 2)                            AS approved_pct,
       ROUND(AVG((shipped_at IS NOT NULL)::INT) * 100, 2)                             AS shipped_pct,
       ROUND(AVG(is_delivered::INT) * 100, 2)                                         AS delivered_pct,
       ROUND(AVG((is_delivered AND NOT is_late)::INT) * 100, 2)                       AS on_time_pct_of_placed,
       ROUND(AVG(is_late::INT) FILTER (WHERE is_delivered) * 100, 2)                  AS late_pct_of_delivered,
       ROUND(AVG((is_delivered AND NOT is_late AND review_score >= 4)::INT) * 100, 2) AS on_time_positive_pct,
       ROUND(AVG(delivery_days) FILTER (WHERE is_delivered), 1)                        AS avg_delivery_days,
       ROUND(ANY_VALUE(rep.r) * 100, 2)                                               AS repurchase_pct
FROM seg s LEFT JOIN rep ON rep.dimension = s.dimension AND rep.segment = s.segment
GROUP BY 1, 2
ORDER BY 1, placed DESC;
