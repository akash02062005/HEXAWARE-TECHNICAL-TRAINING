-- =====================================================================
-- Set 1 - Retail Sales Reporting : reports.sql
-- Database : retail_sales (MySQL 8.0)
-- Revenue  = SUM(order_items.quantity * order_items.unit_price);
--            CANCELLED orders are excluded from every sales figure.
-- =====================================================================
USE retail_sales;

-- Fixed reporting date so that DATEDIFF results are reproducible
SET @report_date = '2026-11-12';

-- ---------------------------------------------------------------------
-- Q1. Top-5 products by revenue
-- ---------------------------------------------------------------------
SELECT  p.product_id,
        UPPER(p.product_name)                           AS product,
        p.category,
        SUM(oi.quantity)                                AS units_sold,
        CONCAT('Rs. ', FORMAT(SUM(oi.quantity * oi.unit_price), 2)) AS revenue
FROM    order_items oi
JOIN    orders   o ON o.order_id   = oi.order_id
JOIN    products p ON p.product_id = oi.product_id
WHERE   o.status <> 'CANCELLED'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY SUM(oi.quantity * oi.unit_price) DESC
LIMIT 5;

-- ---------------------------------------------------------------------
-- Q2. Month-wise sales
-- ---------------------------------------------------------------------
SELECT  DATE_FORMAT(o.order_date, '%Y-%m')              AS month_key,
        DATE_FORMAT(o.order_date, '%M %Y')              AS sales_month,
        COUNT(DISTINCT o.order_id)                      AS total_orders,
        SUM(oi.quantity)                                AS units_sold,
        ROUND(SUM(oi.quantity * oi.unit_price), 2)      AS monthly_revenue
FROM    orders o
JOIN    order_items oi ON oi.order_id = o.order_id
WHERE   o.status <> 'CANCELLED'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m'), DATE_FORMAT(o.order_date, '%M %Y')
ORDER BY month_key;

-- ---------------------------------------------------------------------
-- Q3. Customers with more than three orders (HAVING)
-- ---------------------------------------------------------------------
SELECT  c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name)          AS customer_name,
        UPPER(c.city)                                   AS city,
        COUNT(o.order_id)                               AS order_count,
        DATE_FORMAT(MAX(o.order_date), '%d-%b-%Y')      AS last_order_on
FROM    customers c
JOIN    orders o ON o.customer_id = c.customer_id
WHERE   o.status <> 'CANCELLED'          -- row filter : applied BEFORE grouping
GROUP BY c.customer_id, c.first_name, c.last_name, c.city
HAVING  COUNT(o.order_id) > 3            -- group filter : applied AFTER grouping
ORDER BY order_count DESC, c.customer_id;

-- ---------------------------------------------------------------------
-- Q4. Average basket value per city
--     (basket = total value of one order; averaged over the city's orders)
-- ---------------------------------------------------------------------
SELECT  UPPER(c.city)                                   AS city,
        COUNT(*)                                        AS orders_placed,
        ROUND(SUM(b.basket_value), 2)                   AS total_sales,
        ROUND(AVG(b.basket_value), 2)                   AS avg_basket_value
FROM   (SELECT  oi.order_id,
                SUM(oi.quantity * oi.unit_price) AS basket_value
        FROM    order_items oi
        GROUP BY oi.order_id) b
JOIN    orders    o ON o.order_id    = b.order_id
JOIN    customers c ON c.customer_id = o.customer_id
WHERE   o.status <> 'CANCELLED'
GROUP BY c.city
ORDER BY avg_basket_value DESC;

-- ---------------------------------------------------------------------
-- Q5. Orders without payment (LEFT JOIN)
-- ---------------------------------------------------------------------
SELECT  o.order_id,
        CONCAT(c.first_name, ' ', c.last_name)          AS customer_name,
        DATE_FORMAT(o.order_date, '%d-%b-%Y')           AS ordered_on,
        o.status,
        ROUND(SUM(oi.quantity * oi.unit_price), 2)      AS order_value,
        DATEDIFF(@report_date, o.order_date)            AS days_unpaid
FROM    orders o
LEFT JOIN payments    p  ON p.order_id   = o.order_id
JOIN    customers     c  ON c.customer_id = o.customer_id
JOIN    order_items   oi ON oi.order_id   = o.order_id
WHERE   p.payment_id IS NULL
GROUP BY o.order_id, c.first_name, c.last_name, o.order_date, o.status
ORDER BY o.order_date;

-- ---------------------------------------------------------------------
-- Q6. Customers with no orders
-- ---------------------------------------------------------------------
SELECT  c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name)          AS customer_name,
        LOWER(c.email)                                  AS email,
        UPPER(c.city)                                   AS city,
        DATE_FORMAT(c.signup_date, '%d-%b-%Y')          AS signed_up_on,
        DATEDIFF(@report_date, c.signup_date)           AS days_since_signup
FROM    customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE   o.order_id IS NULL
ORDER BY c.customer_id;

-- ---------------------------------------------------------------------
-- Q7. Product-category revenue share
-- ---------------------------------------------------------------------
SELECT  p.category,
        ROUND(SUM(oi.quantity * oi.unit_price), 2)      AS category_revenue,
        CONCAT(ROUND(100 * SUM(oi.quantity * oi.unit_price) /
               (SELECT SUM(oi2.quantity * oi2.unit_price)
                FROM   order_items oi2
                JOIN   orders o2 ON o2.order_id = oi2.order_id
                WHERE  o2.status <> 'CANCELLED'), 2), ' %') AS revenue_share
FROM    order_items oi
JOIN    orders   o ON o.order_id   = oi.order_id
JOIN    products p ON p.product_id = oi.product_id
WHERE   o.status <> 'CANCELLED'
GROUP BY p.category
ORDER BY category_revenue DESC;

-- ---------------------------------------------------------------------
-- Q8. Day with the highest sales
-- ---------------------------------------------------------------------
SELECT  DATE_FORMAT(o.order_date, '%W, %d %M %Y')       AS best_sales_day,
        COUNT(DISTINCT o.order_id)                      AS orders_on_day,
        ROUND(SUM(oi.quantity * oi.unit_price), 2)      AS day_revenue
FROM    orders o
JOIN    order_items oi ON oi.order_id = o.order_id
WHERE   o.status <> 'CANCELLED'
GROUP BY o.order_date
ORDER BY day_revenue DESC
LIMIT 1;

-- =====================================================================
-- Task 3 : NULL behaviour in COUNT(*), COUNT(column), SUM and AVG
--          orders.discount_amount is NULL when no coupon was used
-- =====================================================================
SELECT  COUNT(*)                                        AS total_orders,
        COUNT(discount_amount)                          AS orders_with_discount_value,
        SUM(discount_amount)                            AS total_discount,
        ROUND(AVG(discount_amount), 2)                  AS avg_ignoring_nulls,
        ROUND(SUM(discount_amount) / COUNT(*), 2)       AS avg_over_all_orders,
        ROUND(AVG(COALESCE(discount_amount, 0)), 2)     AS avg_nulls_as_zero
FROM    orders;

-- Aggregates over a set that contains ONLY NULLs
SELECT  COUNT(*)                                        AS row_count,
        COUNT(discount_amount)                          AS non_null_count,
        SUM(discount_amount)                            AS sum_result,
        AVG(discount_amount)                            AS avg_result
FROM    orders
WHERE   discount_amount IS NULL;

-- =====================================================================
-- Task 4 : WHERE vs HAVING - Q3 with and without the WHERE filter
-- =====================================================================
-- Without WHERE : cancelled orders are counted too
SELECT  CONCAT(c.first_name, ' ', c.last_name)          AS customer_name,
        COUNT(o.order_id)                               AS order_count
FROM    customers c
JOIN    orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING  COUNT(o.order_id) > 3
ORDER BY order_count DESC;

-- This fails : an aggregate cannot be used in WHERE (Error 1111)
-- SELECT customer_id, COUNT(*) FROM orders
-- WHERE COUNT(*) > 3 GROUP BY customer_id;
