-- =====================================================================
--  Set 3 - Telecom Low-Balance Follow-up
--  File   : views.sql
--  Purpose: schema, sample data, vw_prepaid_subscribers and
--           vw_recharge_summary (Task 1)
--  Author : Akash S
--  Server : MySQL 8.0 (InnoDB)
-- =====================================================================

DROP DATABASE IF EXISTS telecom_followup;
CREATE DATABASE telecom_followup;
USE telecom_followup;

-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------
CREATE TABLE plans (
    plan_id        INT           PRIMARY KEY AUTO_INCREMENT,
    plan_code      VARCHAR(10)   NOT NULL UNIQUE,
    plan_name      VARCHAR(40)   NOT NULL,
    plan_type      ENUM('PREPAID','POSTPAID') NOT NULL,
    price          DECIMAL(8,2)  NOT NULL CHECK (price > 0),
    validity_days  INT           NOT NULL,
    data_gb_day    DECIMAL(4,1)  NOT NULL,
    is_active      TINYINT(1)    NOT NULL DEFAULT 1
) ENGINE = InnoDB;

CREATE TABLE subscribers (
    subscriber_id  INT           PRIMARY KEY AUTO_INCREMENT,
    msisdn         CHAR(10)      NOT NULL UNIQUE,
    full_name      VARCHAR(60)   NOT NULL,
    plan_type      ENUM('PREPAID','POSTPAID') NOT NULL,
    plan_id        INT           NOT NULL,
    balance        DECIMAL(10,2) NOT NULL DEFAULT 0,
    validity_end   DATE          NULL,
    status         ENUM('ACTIVE','SUSPENDED') NOT NULL DEFAULT 'ACTIVE',
    circle         VARCHAR(20)   NOT NULL,
    -- sensitive columns: never exposed through the views
    kyc_doc_ref    VARCHAR(20)   NOT NULL,
    date_of_birth  DATE          NOT NULL,
    home_address   VARCHAR(120)  NOT NULL,
    email          VARCHAR(80)   NULL,
    credit_limit   DECIMAL(10,2) NULL,
    activated_on   DATE          NOT NULL,
    CONSTRAINT fk_sub_plan FOREIGN KEY (plan_id) REFERENCES plans (plan_id),
    INDEX idx_sub_type_balance (plan_type, balance)
) ENGINE = InnoDB;

CREATE TABLE recharges (
    recharge_id    INT           PRIMARY KEY AUTO_INCREMENT,
    subscriber_id  INT           NOT NULL,
    plan_id        INT           NOT NULL,
    amount         DECIMAL(8,2)  NOT NULL,
    balance_before DECIMAL(10,2) NOT NULL,
    balance_after  DECIMAL(10,2) NOT NULL,
    channel        VARCHAR(15)   NOT NULL DEFAULT 'APP',
    recharged_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rch_sub  FOREIGN KEY (subscriber_id) REFERENCES subscribers (subscriber_id),
    CONSTRAINT fk_rch_plan FOREIGN KEY (plan_id)       REFERENCES plans (plan_id)
) ENGINE = InnoDB AUTO_INCREMENT = 5001;

CREATE TABLE notifications (
    notification_id   INT           PRIMARY KEY AUTO_INCREMENT,
    subscriber_id     INT           NOT NULL,
    msisdn            CHAR(10)      NOT NULL,
    balance_at_notice DECIMAL(10,2) NOT NULL,
    message           VARCHAR(160)  NOT NULL,
    method            ENUM('CURSOR','SET_BASED') NOT NULL,
    created_at        DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_ntf_sub FOREIGN KEY (subscriber_id) REFERENCES subscribers (subscriber_id)
) ENGINE = InnoDB;

CREATE TABLE recharge_error_log (
    error_id       INT           PRIMARY KEY AUTO_INCREMENT,
    msisdn         CHAR(10)      NULL,
    plan_code      VARCHAR(10)   NULL,
    amount         DECIMAL(8,2)  NULL,
    sql_state      CHAR(5)       NOT NULL,
    error_no       INT           NOT NULL,
    error_message  VARCHAR(255)  NOT NULL,
    logged_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 2. Sample data
-- ---------------------------------------------------------------------
INSERT INTO plans (plan_code, plan_name, plan_type, price, validity_days, data_gb_day, is_active) VALUES
('PR099', 'Smart 99',            'PREPAID',   99.00, 14, 0.5, 1),
('PR199', 'Smart 199',           'PREPAID',  199.00, 28, 1.0, 1),
('PR299', 'Unlimited 299',       'PREPAID',  299.00, 28, 1.5, 1),
('PR719', 'Unlimited 719',       'PREPAID',  719.00, 84, 2.0, 1),
('PR555', 'Legacy 555',          'PREPAID',  555.00, 56, 1.0, 0),
('PO399', 'Postpaid 399',        'POSTPAID', 399.00, 30, 2.5, 1),
('PO799', 'Postpaid Family 799', 'POSTPAID', 799.00, 30, 5.0, 1);

INSERT INTO subscribers
 (msisdn, full_name, plan_type, plan_id, balance, validity_end, status, circle,
  kyc_doc_ref, date_of_birth, home_address, email, credit_limit, activated_on) VALUES
('9845012301','Arjun Sharma',     'PREPAID', 3, 212.40,'2026-12-05','ACTIVE',   'Karnataka','KYC-PP-100231','1998-04-12','12 MG Road, Bengaluru',          'arjun.s@mailbox.in',   NULL,'2023-02-14'),
('9845012302','Divya Nair',       'PREPAID', 2,  18.75,'2026-11-21','ACTIVE',   'Karnataka','KYC-PP-100232','2001-09-03','44 Indiranagar, Bengaluru',      'divya.n@mailbox.in',   NULL,'2024-06-01'),
('9845012303','Karthik Reddy',    'PREPAID', 1,  42.00,'2026-11-18','ACTIVE',   'Telangana','KYC-PP-100233','1995-01-27','8 Banjara Hills, Hyderabad',     NULL,                   NULL,'2022-11-19'),
('9845012304','Sneha Iyer',       'PREPAID', 4, 860.00,'2027-01-30','ACTIVE',   'Tamil Nadu','KYC-PP-100234','1993-07-15','21 Adyar, Chennai',             'sneha.iyer@mailbox.in',NULL,'2021-08-23'),
('9845012305','Rahul Verma',      'PREPAID', 2,   5.10,'2026-11-15','ACTIVE',   'Delhi',    'KYC-PP-100235','2000-12-30','3 Lajpat Nagar, New Delhi',      'rahul.v@mailbox.in',   NULL,'2025-01-05'),
('9845012306','Meera Pillai',     'PREPAID', 3,  50.00,'2026-12-01','ACTIVE',   'Kerala',   'KYC-PP-100236','1997-03-08','17 Kakkanad, Kochi',             NULL,                   NULL,'2023-05-30'),
('9845012307','Vikram Singh',     'PREPAID', 1,  49.99,'2026-11-24','ACTIVE',   'Punjab',   'KYC-PP-100237','1990-10-21','5 Model Town, Ludhiana',         'vikram.s@mailbox.in',  NULL,'2020-03-11'),
('9845012308','Ananya Rao',       'PREPAID', 2, 128.30,'2026-12-12','ACTIVE',   'Karnataka','KYC-PP-100238','2002-05-18','90 Jayanagar, Bengaluru',        'ananya.r@mailbox.in',  NULL,'2024-09-14'),
('9845012309','Farhan Qureshi',   'PREPAID', 1,  12.00,'2026-11-10','SUSPENDED','Maharashtra','KYC-PP-100239','1996-02-02','61 Andheri East, Mumbai',      NULL,                   NULL,'2022-01-20'),
('9845012310','Pooja Deshmukh',   'PREPAID', 3,  31.60,'2026-11-26','ACTIVE',   'Maharashtra','KYC-PP-100240','1999-11-11','14 Kothrud, Pune',             'pooja.d@mailbox.in',   NULL,'2023-07-07'),
('9845012311','Suresh Babu',      'PREPAID', 4, 404.00,'2027-01-08','ACTIVE',   'Tamil Nadu','KYC-PP-100241','1988-06-25','2 Gandhipuram, Coimbatore',     NULL,                   NULL,'2019-12-01'),
('9845012312','Nikhil Joshi',     'PREPAID', 2,   0.00,'2026-11-12','ACTIVE',   'Gujarat',  'KYC-PP-100242','2003-08-09','27 Navrangpura, Ahmedabad',      'nikhil.j@mailbox.in',  NULL,'2025-04-22'),
('9845012313','Lakshmi Menon',    'PREPAID', 1,  77.25,'2026-11-29','ACTIVE',   'Kerala',   'KYC-PP-100243','1994-04-04','9 Vazhuthacaud, Thiruvananthapuram',NULL,                NULL,'2022-06-16'),
('9845012314','Imran Khan',       'PREPAID', 3,  23.40,'2026-11-19','ACTIVE',   'Uttar Pradesh','KYC-PP-100244','1991-01-13','33 Hazratganj, Lucknow',     'imran.k@mailbox.in',   NULL,'2021-10-10'),
('9845012315','Rohan Kapoor',     'POSTPAID',6,   0.00, NULL,       'ACTIVE',   'Delhi',    'KYC-PO-200101','1985-09-19','11 Vasant Vihar, New Delhi',     'rohan.k@corpmail.in', 5000.00,'2018-05-02'),
('9845012316','Priya Malhotra',   'POSTPAID',7,  15.00, NULL,       'ACTIVE',   'Haryana',  'KYC-PO-200102','1987-12-05','70 Sector 45, Gurugram',         'priya.m@corpmail.in', 8000.00,'2019-02-18'),
('9845012317','Aditya Kulkarni',  'POSTPAID',6,  40.00, NULL,       'ACTIVE',   'Maharashtra','KYC-PO-200103','1992-03-22','18 Baner, Pune',               'aditya.k@corpmail.in',3000.00,'2020-09-09'),
('9845012318','Kavya Hegde',      'POSTPAID',7, 120.00, NULL,       'SUSPENDED','Karnataka','KYC-PO-200104','1989-07-30','5 Malleshwaram, Bengaluru',      'kavya.h@corpmail.in', 6000.00,'2017-11-27');

INSERT INTO recharges (subscriber_id, plan_id, amount, balance_before, balance_after, channel, recharged_at) VALUES
( 1, 3, 299.00,  12.40, 311.40, 'APP',    '2026-10-08 09:14:22'),
( 2, 2, 199.00,   4.75, 203.75, 'UPI',    '2026-10-24 18:02:51'),
( 3, 1,  99.00,   6.00, 105.00, 'RETAIL', '2026-11-04 11:40:09'),
( 4, 4, 719.00, 241.00, 960.00, 'APP',    '2026-11-07 21:16:37'),
( 5, 2, 199.00,   1.10, 200.10, 'UPI',    '2026-10-18 07:55:03'),
( 6, 3, 299.00,  11.00, 310.00, 'APP',    '2026-11-03 13:27:45'),
( 7, 1,  99.00,   2.99, 101.99, 'RETAIL', '2026-11-10 16:48:12'),
( 8, 2, 199.00,  20.30, 219.30, 'UPI',    '2026-11-14 10:05:58'),
(10, 3, 299.00,   0.60, 299.60, 'APP',    '2026-10-29 19:31:24'),
(11, 4, 719.00,  85.00, 804.00, 'APP',    '2026-10-15 08:22:16'),
(11, 2, 199.00, 205.00, 404.00, 'UPI',    '2026-11-12 22:10:41'),
(13, 1,  99.00,  10.25, 109.25, 'RETAIL', '2026-11-15 12:36:30'),
(14, 3, 299.00,   4.40, 303.40, 'UPI',    '2026-10-22 17:44:08'),
( 1, 2, 199.00,  13.40, 212.40, 'UPI',    '2026-11-09 20:19:55'),
( 4, 1,  99.00, 112.00, 211.00, 'APP',    '2026-10-02 15:03:12');

-- ---------------------------------------------------------------------
-- 3. Task 1 - Views
-- ---------------------------------------------------------------------

-- vw_prepaid_subscribers: only PREPAID rows, and no KYC reference,
-- date of birth, address, e-mail or credit limit.
CREATE OR REPLACE VIEW vw_prepaid_subscribers AS
SELECT s.subscriber_id,
       s.msisdn,
       s.full_name,
       p.plan_code,
       p.plan_name,
       s.balance,
       s.validity_end,
       s.status,
       s.circle
  FROM subscribers s
  JOIN plans p ON p.plan_id = s.plan_id
 WHERE s.plan_type = 'PREPAID';

-- vw_recharge_summary: recharge totals per prepaid subscriber,
-- built on top of the first view so postpaid users stay hidden.
CREATE OR REPLACE VIEW vw_recharge_summary AS
SELECT v.subscriber_id,
       v.msisdn,
       v.full_name,
       v.balance                        AS current_balance,
       COUNT(r.recharge_id)             AS recharge_count,
       COALESCE(SUM(r.amount), 0)       AS total_recharged,
       MAX(r.recharged_at)              AS last_recharge_at
  FROM vw_prepaid_subscribers v
  LEFT JOIN recharges r ON r.subscriber_id = v.subscriber_id
 GROUP BY v.subscriber_id, v.msisdn, v.full_name, v.balance;

-- ---------------------------------------------------------------------
-- 4. Checks
-- ---------------------------------------------------------------------
SELECT 'plans' AS table_name, COUNT(*) AS row_count FROM plans
UNION ALL SELECT 'subscribers', COUNT(*) FROM subscribers
UNION ALL SELECT 'recharges',   COUNT(*) FROM recharges
UNION ALL SELECT 'notifications', COUNT(*) FROM notifications;

SELECT * FROM vw_prepaid_subscribers ORDER BY subscriber_id;

-- sensitive columns are not part of the view
SELECT kyc_doc_ref FROM vw_prepaid_subscribers;   -- Error 1054: Unknown column

SELECT * FROM vw_recharge_summary ORDER BY total_recharged DESC, subscriber_id;
