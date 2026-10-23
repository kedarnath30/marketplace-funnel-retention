-- 00_views.sql
-- Base model. {RAW} is replaced at runtime with the data/raw/ directory.
-- Grain notes:
--   * customer_id is per-order in Olist; customer_unique_id is the real person -> used as user_id.
--   * Analysis window: purchases from 2017-01-01 to 2018-08-31 (20 complete months;
--     2016 and Sep/Oct 2018 contain only a handful of orders).

CREATE OR REPLACE VIEW raw_orders    AS SELECT * FROM read_csv_auto('{RAW}olist_orders_dataset.csv');
CREATE OR REPLACE VIEW raw_customers AS SELECT * FROM read_csv_auto('{RAW}olist_customers_dataset.csv');
CREATE OR REPLACE VIEW raw_items     AS SELECT * FROM read_csv_auto('{RAW}olist_order_items_dataset.csv');
CREATE OR REPLACE VIEW raw_payments  AS SELECT * FROM read_csv_auto('{RAW}olist_order_payments_dataset.csv');
CREATE OR REPLACE VIEW raw_reviews   AS SELECT * FROM read_csv_auto('{RAW}olist_order_reviews_dataset.csv');
CREATE OR REPLACE VIEW raw_products  AS SELECT * FROM read_csv_auto('{RAW}olist_products_dataset.csv');
CREATE OR REPLACE VIEW raw_cat_en    AS SELECT * FROM read_csv_auto('{RAW}product_category_name_translation.csv');

-- One review per order (latest answer wins; ~0.5% of orders have >1 review)
CREATE OR REPLACE TABLE order_review AS
SELECT order_id, arg_max(review_score, review_answer_timestamp) AS review_score
FROM raw_reviews GROUP BY order_id;

-- Order value and main category (category of the highest-priced item)
CREATE OR REPLACE TABLE order_value AS
SELECT i.order_id,
       SUM(i.price)                         AS item_revenue,
       SUM(i.price + i.freight_value)       AS gmv,
       COUNT(*)                             AS n_items,
       arg_max(COALESCE(c.product_category_name_english, p.product_category_name, 'unknown'), i.price) AS main_category
FROM raw_items i
LEFT JOIN raw_products p USING (product_id)
LEFT JOIN raw_cat_en  c USING (product_category_name)
GROUP BY i.order_id;

-- Primary payment type (largest payment share)
CREATE OR REPLACE TABLE order_payment AS
SELECT order_id, arg_max(payment_type, payment_value) AS payment_type,
       MAX(payment_installments) AS installments
FROM raw_payments GROUP BY order_id;

-- Fact table: one row per order in the analysis window
CREATE OR REPLACE TABLE orders AS
SELECT o.order_id,
       c.customer_unique_id                         AS user_id,
       c.customer_state                             AS state,
       CASE WHEN c.customer_state IN ('SP','RJ','MG','ES') THEN 'Southeast'
            WHEN c.customer_state IN ('PR','SC','RS')      THEN 'South'
            WHEN c.customer_state IN ('DF','GO','MT','MS') THEN 'Center-West'
            WHEN c.customer_state IN ('BA','PE','CE','MA','PB','RN','AL','SE','PI') THEN 'Northeast'
            ELSE 'North' END                        AS region,
       o.order_status,
       o.order_purchase_timestamp                   AS purchased_at,
       o.order_approved_at                          AS approved_at,
       o.order_delivered_carrier_date               AS shipped_at,
       o.order_delivered_customer_date              AS delivered_at,
       o.order_estimated_delivery_date              AS estimated_at,
       o.order_status NOT IN ('canceled','unavailable')            AS is_purchase,
       (o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL) AS is_delivered,
       CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL
            ELSE CAST(o.order_delivered_customer_date AS DATE) > CAST(o.order_estimated_delivery_date AS DATE) END AS is_late,
       date_diff('day', o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_days,
       date_diff('day', CAST(o.order_estimated_delivery_date AS DATE), CAST(o.order_delivered_customer_date AS DATE)) AS days_vs_estimate,
       v.gmv, v.item_revenue, v.n_items, v.main_category,
       p.payment_type, p.installments,
       r.review_score
FROM raw_orders o
JOIN raw_customers c USING (customer_id)
LEFT JOIN order_value   v USING (order_id)
LEFT JOIN order_payment p USING (order_id)
LEFT JOIN order_review  r USING (order_id)
WHERE o.order_purchase_timestamp >= TIMESTAMP '2017-01-01'
  AND o.order_purchase_timestamp <  TIMESTAMP '2018-09-01';

-- Purchases only (excludes canceled / unavailable), ranked per user
CREATE OR REPLACE TABLE purchases AS
SELECT *,
       ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY purchased_at) AS purchase_seq,
       MIN(purchased_at) OVER (PARTITION BY user_id)                  AS first_purchase_at
FROM orders WHERE is_purchase AND gmv IS NOT NULL;

-- Seller-side fact: one row per (seller, purchase order) in the window
CREATE OR REPLACE TABLE seller_orders AS
SELECT i.seller_id, p.order_id, p.purchased_at, p.is_delivered, p.is_late, p.review_score,
       SUM(i.price) AS seller_item_revenue,
       MIN(p.purchased_at) OVER (PARTITION BY i.seller_id) AS seller_first_sale_at
FROM raw_items i
JOIN purchases p USING (order_id)
GROUP BY i.seller_id, p.order_id, p.purchased_at, p.is_delivered, p.is_late, p.review_score;
