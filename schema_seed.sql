-- =====================================================================
-- Set 1 - Retail Sales Reporting : schema and sample data
-- Target : MySQL 8.0 (InnoDB)
-- =====================================================================
DROP DATABASE IF EXISTS retail_sales;
CREATE DATABASE retail_sales;
USE retail_sales;

CREATE TABLE customers (
    customer_id  INT          PRIMARY KEY,
    first_name   VARCHAR(40)  NOT NULL,
    last_name    VARCHAR(40)  NOT NULL,
    email        VARCHAR(80)  NOT NULL UNIQUE,
    city         VARCHAR(40)  NOT NULL,
    signup_date  DATE         NOT NULL
) ENGINE = InnoDB;

CREATE TABLE products (
    product_id    INT            PRIMARY KEY,
    product_name  VARCHAR(60)    NOT NULL,
    category      VARCHAR(40)    NOT NULL,
    unit_price    DECIMAL(10,2)  NOT NULL CHECK (unit_price >= 0)
) ENGINE = InnoDB;

CREATE TABLE orders (
    order_id         INT            PRIMARY KEY,
    customer_id      INT            NOT NULL,
    order_date       DATE           NOT NULL,
    status           VARCHAR(12)    NOT NULL DEFAULT 'DELIVERED',
    discount_amount  DECIMAL(10,2)  NULL,          -- NULL = no coupon used
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
) ENGINE = InnoDB;

CREATE TABLE order_items (
    order_id    INT            NOT NULL,
    product_id  INT            NOT NULL,
    quantity    INT            NOT NULL CHECK (quantity > 0),
    unit_price  DECIMAL(10,2)  NOT NULL,           -- price at time of sale
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_items_order   FOREIGN KEY (order_id)   REFERENCES orders (order_id),
    CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products (product_id)
) ENGINE = InnoDB;

CREATE TABLE payments (
    payment_id    INT            PRIMARY KEY,
    order_id      INT            NOT NULL UNIQUE,
    payment_date  DATE           NOT NULL,
    method        VARCHAR(20)    NOT NULL,
    amount        DECIMAL(10,2)  NOT NULL,
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders (order_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Sample data
-- ---------------------------------------------------------------------
INSERT INTO customers VALUES
 (1,  'Arjun',   'Rao',      'arjun.rao@mail.com',      'Bengaluru', '2026-06-02'),
 (2,  'Priya',   'Nair',     'priya.nair@mail.com',     'Chennai',   '2026-06-10'),
 (3,  'Rahul',   'Sharma',   'rahul.sharma@mail.com',   'Mumbai',    '2026-06-15'),
 (4,  'Sneha',   'Iyer',     'sneha.iyer@mail.com',     'Bengaluru', '2026-07-01'),
 (5,  'Karthik', 'Reddy',    'karthik.reddy@mail.com',  'Hyderabad', '2026-07-05'),
 (6,  'Ananya',  'Gupta',    'ananya.gupta@mail.com',   'Delhi',     '2026-07-12'),
 (7,  'Vikram',  'Singh',    'vikram.singh@mail.com',   'Mumbai',    '2026-07-20'),
 (8,  'Divya',   'Menon',    'divya.menon@mail.com',    'Chennai',   '2026-08-01'),
 (9,  'Rohan',   'Das',      'rohan.das@mail.com',      'Hyderabad', '2026-08-03'),
 (10, 'Meera',   'Pillai',   'meera.pillai@mail.com',   'Bengaluru', '2026-08-18'),
 (11, 'Farhan',  'Ali',      'farhan.ali@mail.com',     'Delhi',     '2026-09-09'),
 (12, 'Lakshmi', 'Krishnan', 'lakshmi.k@mail.com',      'Chennai',   '2026-10-14');

INSERT INTO products VALUES
 (101, 'Wireless Earbuds',        'Electronics',    2499.00),
 (102, 'Smart Watch',             'Electronics',    4999.00),
 (103, 'Bluetooth Speaker',       'Electronics',    1799.00),
 (104, 'Non-stick Cookware Set',  'Home & Kitchen', 3299.00),
 (105, 'Mixer Grinder',           'Home & Kitchen', 2899.00),
 (106, 'Cotton Kurta',            'Fashion',         899.00),
 (107, 'Running Shoes',           'Fashion',        2199.00),
 (108, 'Basmati Rice 5 kg',       'Grocery',         649.00),
 (109, 'Filter Coffee 500 g',     'Grocery',         320.00),
 (110, 'SQL Fundamentals (Book)', 'Books',           550.00);

INSERT INTO orders (order_id, customer_id, order_date, status, discount_amount) VALUES
 (1001, 1,  '2026-08-03', 'DELIVERED', NULL),
 (1002, 2,  '2026-08-05', 'DELIVERED', 100.00),
 (1003, 3,  '2026-08-09', 'DELIVERED', NULL),
 (1004, 1,  '2026-08-14', 'DELIVERED', 200.00),
 (1005, 4,  '2026-08-21', 'DELIVERED', NULL),
 (1006, 5,  '2026-08-27', 'DELIVERED', 50.00),
 (1007, 2,  '2026-09-02', 'DELIVERED', NULL),
 (1008, 3,  '2026-09-06', 'CANCELLED', NULL),
 (1009, 6,  '2026-09-11', 'DELIVERED', 150.00),
 (1010, 1,  '2026-09-15', 'DELIVERED', NULL),
 (1011, 7,  '2026-09-18', 'DELIVERED', NULL),
 (1012, 8,  '2026-09-24', 'DELIVERED', 0.00),
 (1013, 2,  '2026-09-29', 'DELIVERED', NULL),
 (1014, 9,  '2026-10-04', 'DELIVERED', NULL),
 (1015, 3,  '2026-10-08', 'DELIVERED', 100.00),
 (1016, 1,  '2026-10-20', 'DELIVERED', 300.00),
 (1017, 10, '2026-10-20', 'DELIVERED', NULL),
 (1018, 4,  '2026-10-20', 'DELIVERED', 250.00),
 (1019, 2,  '2026-10-25', 'SHIPPED',   NULL),
 (1020, 3,  '2026-10-29', 'SHIPPED',   NULL),
 (1021, 1,  '2026-11-02', 'PLACED',    NULL),
 (1022, 6,  '2026-11-05', 'PLACED',    NULL);

INSERT INTO order_items VALUES
 (1001, 101, 1, 2499.00), (1001, 109, 2, 320.00),
 (1002, 106, 2,  899.00), (1002, 108, 1, 649.00),
 (1003, 102, 1, 4999.00),
 (1004, 104, 1, 3299.00), (1004, 110, 1, 550.00),
 (1005, 107, 1, 2199.00), (1005, 109, 3, 320.00),
 (1006, 103, 1, 1799.00),
 (1007, 105, 1, 2899.00), (1007, 108, 2, 649.00),
 (1008, 102, 1, 4999.00),
 (1009, 101, 2, 2499.00),
 (1010, 106, 1,  899.00), (1010, 109, 1, 320.00),
 (1011, 107, 2, 2199.00), (1011, 110, 1, 550.00),
 (1012, 108, 3,  649.00),
 (1013, 103, 1, 1799.00), (1013, 106, 1, 899.00),
 (1014, 104, 1, 3299.00),
 (1015, 101, 1, 2499.00), (1015, 103, 1, 1799.00),
 (1016, 102, 1, 4999.00), (1016, 105, 1, 2899.00),
 (1017, 104, 1, 3299.00), (1017, 107, 1, 2199.00),
 (1018, 102, 1, 4999.00), (1018, 101, 1, 2499.00),
 (1019, 110, 2,  550.00), (1019, 109, 2, 320.00),
 (1020, 107, 1, 2199.00),
 (1021, 108, 2,  649.00),
 (1022, 105, 1, 2899.00);

-- Orders 1008 (cancelled), 1021 and 1022 (just placed) have no payment yet
INSERT INTO payments VALUES
 (1,  1001, '2026-08-03', 'UPI',         3139.00),
 (2,  1002, '2026-08-05', 'Card',        2347.00),
 (3,  1003, '2026-08-09', 'Net Banking', 4999.00),
 (4,  1004, '2026-08-14', 'UPI',         3649.00),
 (5,  1005, '2026-08-21', 'Card',        3159.00),
 (6,  1006, '2026-08-27', 'UPI',         1749.00),
 (7,  1007, '2026-09-02', 'Cash',        4197.00),
 (8,  1009, '2026-09-11', 'Card',        4848.00),
 (9,  1010, '2026-09-15', 'UPI',         1219.00),
 (10, 1011, '2026-09-18', 'Card',        4948.00),
 (11, 1012, '2026-09-24', 'UPI',         1947.00),
 (12, 1013, '2026-09-29', 'Card',        2698.00),
 (13, 1014, '2026-10-04', 'Net Banking', 3299.00),
 (14, 1015, '2026-10-08', 'UPI',         4198.00),
 (15, 1016, '2026-10-20', 'Card',        7598.00),
 (16, 1017, '2026-10-20', 'UPI',         5498.00),
 (17, 1018, '2026-10-20', 'Card',        7248.00),
 (18, 1019, '2026-10-25', 'UPI',         1740.00),
 (19, 1020, '2026-10-29', 'Cash',        2199.00);
