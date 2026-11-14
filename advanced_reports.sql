-- =====================================================================
--  advanced_reports.sql
--  Set 2 - Bank Loan Portfolio : joins, self join, correlated and
--  uncorrelated subqueries, EXISTS / NOT EXISTS and nested subqueries
--  Target : MySQL 8.0 (tested on MySQL 8.0 Workbench)
-- =====================================================================

DROP DATABASE IF EXISTS bank_loans;
CREATE DATABASE bank_loans;
USE bank_loans;

-- ---------------------------------------------------------------------
-- 1. SCHEMA
-- ---------------------------------------------------------------------
CREATE TABLE branches (
    branch_id    INT          PRIMARY KEY,
    branch_name  VARCHAR(60)  NOT NULL,
    city         VARCHAR(40)  NOT NULL,
    ifsc_code    CHAR(11)     NOT NULL UNIQUE,
    opened_on    DATE         NOT NULL
) ENGINE = InnoDB;

CREATE TABLE customers (
    customer_id     INT          PRIMARY KEY,
    full_name       VARCHAR(60)  NOT NULL,
    city            VARCHAR(40)  NOT NULL,
    phone           CHAR(10)     NOT NULL,
    customer_since  DATE         NOT NULL,
    home_branch_id  INT          NOT NULL,
    CONSTRAINT fk_cust_branch FOREIGN KEY (home_branch_id) REFERENCES branches (branch_id)
) ENGINE = InnoDB;

CREATE TABLE loans (
    loan_id         INT            PRIMARY KEY,
    customer_id     INT            NOT NULL,
    branch_id       INT            NOT NULL,
    loan_type       VARCHAR(12)    NOT NULL,
    principal       DECIMAL(12,2)  NOT NULL,
    interest_rate   DECIMAL(5,2)   NOT NULL,
    tenure_months   INT            NOT NULL,
    emi_amount      DECIMAL(10,2)  NOT NULL,
    disbursed_on    DATE           NOT NULL,
    first_emi_date  DATE           NOT NULL,
    status          VARCHAR(10)    NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT fk_loan_cust   FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
    CONSTRAINT fk_loan_branch FOREIGN KEY (branch_id)   REFERENCES branches (branch_id),
    CONSTRAINT chk_loan_status CHECK (status IN ('ACTIVE', 'CLOSED'))
) ENGINE = InnoDB;

CREATE TABLE repayments (
    repayment_id    INT            PRIMARY KEY,
    loan_id         INT            NOT NULL,
    instalment_no   INT            NOT NULL,
    paid_on         DATE           NOT NULL,
    amount          DECIMAL(10,2)  NOT NULL,
    CONSTRAINT fk_rep_loan FOREIGN KEY (loan_id) REFERENCES loans (loan_id),
    CONSTRAINT uq_rep_inst UNIQUE (loan_id, instalment_no)
) ENGINE = InnoDB;

-- A guarantor may be an outside person (customer_id NULL) or an
-- existing bank customer (customer_id filled in).
CREATE TABLE guarantors (
    guarantor_id    INT          PRIMARY KEY,
    loan_id         INT          NOT NULL,
    guarantor_name  VARCHAR(60)  NOT NULL,
    relationship    VARCHAR(20)  NOT NULL,
    customer_id     INT          NULL,
    CONSTRAINT fk_guar_loan FOREIGN KEY (loan_id)     REFERENCES loans (loan_id),
    CONSTRAINT fk_guar_cust FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
) ENGINE = InnoDB;

CREATE INDEX idx_loans_customer   ON loans (customer_id);
CREATE INDEX idx_loans_branch     ON loans (branch_id);
CREATE INDEX idx_rep_loan_paid    ON repayments (loan_id, paid_on);

-- ---------------------------------------------------------------------
-- 2. SAMPLE DATA
-- ---------------------------------------------------------------------
INSERT INTO branches VALUES
(1, 'Jayanagar',     'Bengaluru', 'BLPB0000101', '2012-04-02'),
(2, 'Whitefield',    'Bengaluru', 'BLPB0000102', '2015-07-15'),
(3, 'T. Nagar',      'Chennai',   'BLPB0000201', '2013-01-10'),
(4, 'Banjara Hills', 'Hyderabad', 'BLPB0000301', '2014-09-22'),
(5, 'Andheri East',  'Mumbai',    'BLPB0000401', '2011-11-01'),
(6, 'Gokulam',       'Mysuru',    'BLPB0000103', '2026-08-17'),
(7, 'RS Puram',      'Coimbatore','BLPB0000202', '2026-10-05');

INSERT INTO customers VALUES
( 1, 'Arjun Rao',            'Bengaluru', '9845012345', '2016-03-11', 1),
( 2, 'Priya Nair',           'Bengaluru', '9880123456', '2018-06-25', 2),
( 3, 'Rahul Sharma',         'Mumbai',    '9820234567', '2014-01-08', 5),
( 4, 'Sneha Iyer',           'Chennai',   '9840345678', '2019-08-19', 3),
( 5, 'Vikram Reddy',         'Hyderabad', '9848456789', '2015-12-02', 4),
( 6, 'Meera Joshi',          'Mumbai',    '9821567890', '2017-05-30', 5),
( 7, 'Karthik Subramanian',  'Chennai',   '9841678901', '2020-02-14', 3),
( 8, 'Ananya Gupta',         'Bengaluru', '9886789012', '2021-09-07', 1),
( 9, 'Rohan Das',            'Hyderabad', '9849890123', '2019-11-21', 4),
(10, 'Divya Menon',          'Bengaluru', '9845901234', '2022-04-18', 2),
(11, 'Suresh Patil',         'Mumbai',    '9822012345', '2016-10-03', 5),
(12, 'Kavya Hegde',          'Bengaluru', '9880234561', '2023-01-27', 1),
(13, 'Imran Khan',           'Hyderabad', '9848345612', '2018-07-09', 4),
(14, 'Pooja Verma',          'Chennai',   '9840456123', '2024-03-15', 3);

-- loan_id, customer_id, branch_id, loan_type, principal, interest_rate,
-- tenure_months, emi_amount, disbursed_on, first_emi_date, status
INSERT INTO loans VALUES
(5001, 1, 1, 'HOME', 3500000.00, 8.40, 240, 30152.66, '2025-05-10', '2025-06-05', 'ACTIVE'),
(5002, 1, 2, 'VEHICLE', 850000.00, 9.25, 60, 17747.91, '2025-10-14', '2025-11-10', 'ACTIVE'),
(5003, 2, 2, 'PERSONAL', 400000.00, 12.50, 36, 13381.45, '2025-11-03', '2025-12-01', 'ACTIVE'),
(5004, 3, 5, 'HOME', 6200000.00, 8.60, 300, 50342.58, '2025-02-12', '2025-03-15', 'ACTIVE'),
(5005, 3, 1, 'PERSONAL', 300000.00, 13.00, 24, 14262.55, '2026-01-12', '2026-02-10', 'ACTIVE'),
(5006, 4, 3, 'EDUCATION', 1200000.00, 9.50, 84, 19612.78, '2025-12-18', '2026-01-20', 'ACTIVE'),
(5007, 5, 4, 'HOME', 2800000.00, 8.75, 180, 27984.56, '2024-10-04', '2024-11-01', 'ACTIVE'),
(5008, 5, 4, 'GOLD', 250000.00, 10.00, 12, 21978.97, '2025-08-06', '2025-09-01', 'CLOSED'),
(5009, 6, 5, 'VEHICLE', 950000.00, 9.10, 60, 19766.58, '2025-07-08', '2025-08-05', 'ACTIVE'),
(5010, 7, 3, 'PERSONAL', 500000.00, 12.75, 48, 13351.79, '2025-09-15', '2025-10-12', 'ACTIVE'),
(5011, 8, 1, 'VEHICLE', 700000.00, 9.30, 60, 14632.98, '2026-02-09', '2026-03-08', 'ACTIVE'),
(5012, 9, 4, 'PERSONAL', 350000.00, 13.50, 36, 11877.35, '2025-06-20', '2025-07-18', 'ACTIVE'),
(5013, 10, 2, 'HOME', 4000000.00, 8.45, 240, 34586.45, '2026-03-06', '2026-04-05', 'ACTIVE'),
(5014, 11, 5, 'PERSONAL', 600000.00, 12.90, 48, 16066.73, '2025-04-11', '2025-05-10', 'ACTIVE'),
(5015, 12, 1, 'EDUCATION', 900000.00, 9.60, 72, 16492.28, '2026-06-16', '2026-07-15', 'ACTIVE'),
(5016, 13, 4, 'VEHICLE', 1100000.00, 9.20, 60, 22941.11, '2025-12-22', '2026-01-25', 'ACTIVE'),
(5017, 13, 3, 'GOLD', 180000.00, 10.50, 12, 15866.75, '2026-05-04', '2026-06-01', 'ACTIVE'),
(5018, 14, 3, 'PERSONAL', 250000.00, 13.20, 24, 11908.95, '2026-10-01', '2026-10-30', 'ACTIVE'),
(5019, 2, 1, 'GOLD', 150000.00, 10.00, 12, 13187.38, '2026-04-14', '2026-05-12', 'ACTIVE');

-- repayment_id, loan_id, instalment_no, paid_on, amount
INSERT INTO repayments VALUES
(1, 5001, 1, '2025-06-06', 30152.66),
(2, 5001, 2, '2025-07-05', 30152.66),
(3, 5001, 3, '2025-08-07', 30152.66),
(4, 5001, 4, '2025-09-05', 30152.66),
(5, 5001, 5, '2025-10-08', 30152.66),
(6, 5001, 6, '2025-11-06', 30152.66),
(7, 5001, 7, '2025-12-05', 30152.66),
(8, 5001, 8, '2026-01-05', 30152.66),
(9, 5001, 9, '2026-02-07', 30152.66),
(10, 5001, 10, '2026-03-06', 30152.66),
(11, 5001, 11, '2026-04-05', 30152.66),
(12, 5001, 12, '2026-05-09', 30152.66),
(13, 5001, 13, '2026-06-05', 30152.66),
(14, 5001, 14, '2026-07-06', 30152.66),
(15, 5001, 15, '2026-08-05', 30152.66),
(16, 5001, 16, '2026-09-06', 30152.66),
(17, 5001, 17, '2026-10-05', 30152.66),
(18, 5001, 18, '2026-11-07', 30152.66),
(19, 5002, 1, '2025-11-10', 17747.91),
(20, 5002, 2, '2025-12-12', 17747.91),
(21, 5002, 3, '2026-01-10', 17747.91),
(22, 5002, 4, '2026-02-13', 17747.91),
(23, 5002, 5, '2026-03-11', 17747.91),
(24, 5002, 6, '2026-04-10', 17747.91),
(25, 5002, 7, '2026-05-10', 17747.91),
(26, 5002, 8, '2026-06-12', 17747.91),
(27, 5002, 9, '2026-07-11', 17747.91),
(28, 5002, 10, '2026-08-10', 17747.91),
(29, 5002, 11, '2026-09-14', 17747.91),
(30, 5002, 12, '2026-10-10', 17747.91),
(31, 5002, 13, '2026-11-11', 17747.91),
(32, 5003, 1, '2025-12-03', 13381.45),
(33, 5003, 2, '2026-01-01', 13381.45),
(34, 5003, 3, '2026-02-04', 13381.45),
(35, 5003, 4, '2026-03-02', 13381.45),
(36, 5003, 5, '2026-04-01', 13381.45),
(37, 5003, 6, '2026-05-01', 13381.45),
(38, 5003, 7, '2026-06-03', 13381.45),
(39, 5004, 1, '2025-03-15', 50342.58),
(40, 5004, 2, '2025-04-18', 50342.58),
(41, 5004, 3, '2025-05-16', 50342.58),
(42, 5004, 4, '2025-06-15', 50342.58),
(43, 5004, 5, '2025-07-15', 50342.58),
(44, 5004, 6, '2025-08-17', 50342.58),
(45, 5004, 7, '2025-09-16', 50342.58),
(46, 5004, 8, '2025-10-15', 50342.58),
(47, 5004, 9, '2025-11-19', 50342.58),
(48, 5004, 10, '2025-12-15', 50342.58),
(49, 5004, 11, '2026-01-16', 50342.58),
(50, 5004, 12, '2026-02-15', 50342.58),
(51, 5004, 13, '2026-03-16', 50342.58),
(52, 5004, 14, '2026-04-15', 50342.58),
(53, 5004, 15, '2026-05-17', 50342.58),
(54, 5004, 16, '2026-06-15', 50342.58),
(55, 5004, 17, '2026-07-18', 50342.58),
(56, 5004, 18, '2026-08-16', 50342.58),
(57, 5004, 19, '2026-09-15', 50342.58),
(58, 5004, 20, '2026-10-15', 50342.58),
(59, 5005, 1, '2026-02-13', 14262.55),
(60, 5005, 2, '2026-03-11', 14262.55),
(61, 5005, 3, '2026-04-10', 14262.55),
(62, 5005, 4, '2026-05-10', 14262.55),
(63, 5005, 5, '2026-06-12', 14262.55),
(64, 5005, 6, '2026-07-11', 14262.55),
(65, 5005, 7, '2026-08-10', 14262.55),
(66, 5005, 8, '2026-09-14', 14262.55),
(67, 5005, 9, '2026-10-10', 14262.55),
(68, 5005, 10, '2026-11-11', 14262.55),
(69, 5006, 1, '2026-01-21', 19612.78),
(70, 5006, 2, '2026-02-20', 19612.78),
(71, 5006, 3, '2026-03-20', 19612.78),
(72, 5006, 4, '2026-04-22', 19612.78),
(73, 5006, 5, '2026-05-21', 19612.78),
(74, 5006, 6, '2026-06-20', 19612.78),
(75, 5006, 7, '2026-07-24', 19612.78),
(76, 5006, 8, '2026-08-20', 19612.78),
(77, 5007, 1, '2024-11-01', 27984.56),
(78, 5007, 2, '2024-12-01', 27984.56),
(79, 5007, 3, '2025-01-03', 27984.56),
(80, 5007, 4, '2025-02-02', 27984.56),
(81, 5007, 5, '2025-03-01', 27984.56),
(82, 5007, 6, '2025-04-05', 27984.56),
(83, 5007, 7, '2025-05-01', 27984.56),
(84, 5007, 8, '2025-06-02', 27984.56),
(85, 5007, 9, '2025-07-01', 27984.56),
(86, 5007, 10, '2025-08-02', 27984.56),
(87, 5007, 11, '2025-09-01', 27984.56),
(88, 5007, 12, '2025-10-03', 27984.56),
(89, 5007, 13, '2025-11-01', 27984.56),
(90, 5007, 14, '2025-12-04', 27984.56),
(91, 5007, 15, '2026-01-02', 27984.56),
(92, 5007, 16, '2026-02-01', 27984.56),
(93, 5007, 17, '2026-03-01', 27984.56),
(94, 5007, 18, '2026-04-03', 27984.56),
(95, 5007, 19, '2026-05-02', 27984.56),
(96, 5007, 20, '2026-06-01', 27984.56),
(97, 5007, 21, '2026-07-05', 27984.56),
(98, 5007, 22, '2026-08-01', 27984.56),
(99, 5007, 23, '2026-09-02', 27984.56),
(100, 5007, 24, '2026-10-01', 27984.56),
(101, 5007, 25, '2026-11-02', 27984.56),
(102, 5008, 1, '2025-09-01', 21978.97),
(103, 5008, 2, '2025-10-03', 21978.97),
(104, 5008, 3, '2025-11-02', 21978.97),
(105, 5008, 4, '2025-12-01', 21978.97),
(106, 5008, 5, '2026-01-05', 21978.97),
(107, 5008, 6, '2026-02-01', 21978.97),
(108, 5008, 7, '2026-03-02', 21978.97),
(109, 5008, 8, '2026-04-01', 21978.97),
(110, 5008, 9, '2026-05-02', 21978.97),
(111, 5008, 10, '2026-06-01', 21978.97),
(112, 5008, 11, '2026-07-03', 21978.97),
(113, 5008, 12, '2026-08-01', 21978.97),
(114, 5009, 1, '2025-08-07', 19766.58),
(115, 5009, 2, '2025-09-06', 19766.58),
(116, 5009, 3, '2025-10-05', 19766.58),
(117, 5009, 4, '2025-11-09', 19766.58),
(118, 5009, 5, '2025-12-05', 19766.58),
(119, 5009, 6, '2026-01-06', 19766.58),
(120, 5009, 7, '2026-02-05', 19766.58),
(121, 5009, 8, '2026-03-06', 19766.58),
(122, 5009, 9, '2026-04-05', 19766.58),
(123, 5009, 10, '2026-05-07', 19766.58),
(124, 5009, 11, '2026-06-05', 19766.58),
(125, 5010, 1, '2025-10-13', 13351.79),
(126, 5010, 2, '2025-11-12', 13351.79),
(127, 5010, 3, '2025-12-16', 13351.79),
(128, 5010, 4, '2026-01-12', 13351.79),
(129, 5010, 5, '2026-02-13', 13351.79),
(130, 5010, 6, '2026-03-12', 13351.79),
(131, 5010, 7, '2026-04-13', 13351.79),
(132, 5010, 8, '2026-05-12', 13351.79),
(133, 5010, 9, '2026-06-14', 13351.79),
(134, 5010, 10, '2026-07-12', 13351.79),
(135, 5010, 11, '2026-08-15', 13351.79),
(136, 5010, 12, '2026-09-13', 13351.79),
(137, 5010, 13, '2026-10-12', 13351.79),
(138, 5011, 1, '2026-03-08', 14632.98),
(139, 5011, 2, '2026-04-12', 14632.98),
(140, 5011, 3, '2026-05-08', 14632.98),
(141, 5011, 4, '2026-06-09', 14632.98),
(142, 5011, 5, '2026-07-08', 14632.98),
(143, 5011, 6, '2026-08-09', 14632.98),
(144, 5011, 7, '2026-09-08', 14632.98),
(145, 5011, 8, '2026-10-10', 14632.98),
(146, 5011, 9, '2026-11-08', 14632.98),
(147, 5012, 1, '2025-07-22', 11877.35),
(148, 5012, 2, '2025-08-18', 11877.35),
(149, 5012, 3, '2025-09-19', 11877.35),
(150, 5012, 4, '2025-10-18', 11877.35),
(151, 5012, 5, '2025-11-19', 11877.35),
(152, 5012, 6, '2025-12-18', 11877.35),
(153, 5012, 7, '2026-01-20', 11877.35),
(154, 5012, 8, '2026-02-18', 11877.35),
(155, 5012, 9, '2026-03-21', 11877.35),
(156, 5012, 10, '2026-04-19', 11877.35),
(157, 5012, 11, '2026-07-30', 11877.35),
(158, 5012, 12, '2026-09-25', 11877.35),
(159, 5013, 1, '2026-04-05', 34586.45),
(160, 5013, 2, '2026-05-06', 34586.45),
(161, 5013, 3, '2026-06-05', 34586.45),
(162, 5013, 4, '2026-07-06', 34586.45),
(163, 5013, 5, '2026-08-05', 34586.45),
(164, 5013, 6, '2026-09-07', 34586.45),
(165, 5013, 7, '2026-10-05', 34586.45),
(166, 5013, 8, '2026-11-08', 34586.45),
(167, 5014, 1, '2025-05-11', 16066.73),
(168, 5014, 2, '2025-06-10', 16066.73),
(169, 5014, 3, '2025-07-11', 16066.73),
(170, 5014, 4, '2025-08-10', 16066.73),
(171, 5014, 5, '2025-09-12', 16066.73),
(172, 5014, 6, '2025-10-10', 16066.73),
(173, 5014, 7, '2025-11-13', 16066.73),
(174, 5014, 8, '2025-12-11', 16066.73),
(175, 5014, 9, '2026-01-10', 16066.73),
(176, 5014, 10, '2026-02-10', 16066.73),
(177, 5014, 11, '2026-03-12', 16066.73),
(178, 5014, 12, '2026-04-11', 16066.73),
(179, 5014, 13, '2026-05-10', 16066.73),
(180, 5015, 1, '2026-07-15', 16492.28),
(181, 5015, 2, '2026-08-16', 16492.28),
(182, 5015, 3, '2026-09-15', 16492.28),
(183, 5015, 4, '2026-10-17', 16492.28),
(184, 5016, 1, '2026-01-26', 22941.11),
(185, 5016, 2, '2026-02-25', 22941.11),
(186, 5016, 3, '2026-03-27', 22941.11),
(187, 5016, 4, '2026-04-25', 22941.11),
(188, 5016, 5, '2026-05-28', 22941.11),
(189, 5016, 6, '2026-06-26', 22941.11),
(190, 5016, 7, '2026-07-25', 22941.11),
(191, 5016, 8, '2026-08-25', 22941.11),
(192, 5016, 9, '2026-09-27', 22941.11),
(193, 5016, 10, '2026-10-26', 22941.11),
(194, 5017, 1, '2026-06-01', 15866.75),
(195, 5017, 2, '2026-07-03', 15866.75),
(196, 5017, 3, '2026-08-01', 15866.75),
(197, 5017, 4, '2026-09-04', 15866.75),
(198, 5017, 5, '2026-10-02', 15866.75),
(199, 5017, 6, '2026-11-01', 15866.75),
(200, 5019, 1, '2026-05-12', 13187.38),
(201, 5019, 2, '2026-06-15', 13187.38),
(202, 5019, 3, '2026-07-13', 13187.38),
(203, 5019, 4, '2026-08-12', 13187.38),
(204, 5019, 5, '2026-09-12', 13187.38),
(205, 5019, 6, '2026-10-14', 13187.38),
(206, 5019, 7, '2026-11-13', 13187.38);

INSERT INTO guarantors VALUES
( 1, 5001, 'Ananya Gupta',  'Colleague', 8),
( 2, 5004, 'Meera Joshi',   'Friend',    6),
( 3, 5007, 'Lakshmi Reddy', 'Spouse',    NULL),
( 4, 5013, 'Arjun Rao',     'Friend',    1),
( 5, 5009, 'Ramesh Joshi',  'Father',    NULL),
( 6, 5006, 'Venkat Iyer',   'Father',    NULL),
( 7, 5014, 'Rahul Sharma',  'Relative',  3),
( 8, 5003, 'Divya Menon',   'Colleague', 10),
( 9, 5010, 'Raghavan S',    'Father',    NULL),
(10, 5011, 'Nitin Gupta',   'Brother',   NULL);

-- Row count check after loading the data
SELECT 'branches' AS table_name, COUNT(*) AS row_count FROM branches
UNION ALL SELECT 'customers',  COUNT(*) FROM customers
UNION ALL SELECT 'loans',      COUNT(*) FROM loans
UNION ALL SELECT 'repayments', COUNT(*) FROM repayments
UNION ALL SELECT 'guarantors', COUNT(*) FROM guarantors;

-- Fixed report date so that every date-based answer is reproducible
SET @report_date = '2026-11-14';

-- =====================================================================
-- 3. TASK 1 - TEN QUESTIONS
-- =====================================================================

-- Q1. Loans overdue by more than three instalments
--     Instalments due  = months from first EMI date to report date + 1
--     Instalments paid = rows in repayments (LEFT JOIN keeps unpaid loans)
SELECT  l.loan_id,
        c.full_name,
        b.branch_name,
        l.loan_type,
        LEAST(TIMESTAMPDIFF(MONTH, l.first_emi_date, @report_date) + 1,
              l.tenure_months)                         AS emi_due,
        COUNT(r.repayment_id)                          AS emi_paid,
        LEAST(TIMESTAMPDIFF(MONTH, l.first_emi_date, @report_date) + 1,
              l.tenure_months) - COUNT(r.repayment_id) AS emi_overdue
FROM    loans l
JOIN    customers c       ON c.customer_id = l.customer_id
JOIN    branches  b       ON b.branch_id   = l.branch_id
LEFT JOIN repayments r    ON r.loan_id     = l.loan_id
WHERE   l.status = 'ACTIVE'
GROUP BY l.loan_id, c.full_name, b.branch_name, l.loan_type,
         l.first_emi_date, l.tenure_months
HAVING  emi_overdue > 3
ORDER BY emi_overdue DESC, l.loan_id;

-- Q2. Customers who hold loans in more than one branch
SELECT  c.customer_id,
        c.full_name,
        COUNT(DISTINCT l.branch_id)                        AS branches,
        GROUP_CONCAT(DISTINCT b.branch_name
                     ORDER BY b.branch_name SEPARATOR ', ') AS branch_list,
        COUNT(*)                                           AS loans
FROM    customers c
JOIN    loans    l ON l.customer_id = c.customer_id
JOIN    branches b ON b.branch_id   = l.branch_id
GROUP BY c.customer_id, c.full_name
HAVING  COUNT(DISTINCT l.branch_id) > 1
ORDER BY c.customer_id;

-- Q3. Guarantors who are also borrowers (SELF JOIN on customers)
--     g = the customer acting as guarantor, b = the borrower guaranteed
SELECT  g.customer_id                 AS guarantor_cust_id,
        g.full_name                   AS guarantor,
        gr.relationship,
        gl.loan_id                    AS guaranteed_loan,
        b.full_name                   AS borrower,
        (SELECT COUNT(*) FROM loans x
          WHERE x.customer_id = g.customer_id) AS own_loans
FROM    guarantors gr
JOIN    customers  g  ON g.customer_id  = gr.customer_id
JOIN    loans      gl ON gl.loan_id     = gr.loan_id
JOIN    customers  b  ON b.customer_id  = gl.customer_id
WHERE   EXISTS (SELECT 1 FROM loans ol WHERE ol.customer_id = g.customer_id)
ORDER BY g.customer_id;

-- Q4. Branches with no loans (LEFT JOIN ... IS NULL)
SELECT  b.branch_id,
        b.branch_name,
        b.city,
        b.opened_on,
        DATEDIFF(@report_date, b.opened_on) AS days_open
FROM    branches b
LEFT JOIN loans l ON l.branch_id = b.branch_id
WHERE   l.loan_id IS NULL
ORDER BY b.branch_id;

-- Q5. Branch-wise portfolio summary (all branches, incl. zero loans)
SELECT  b.branch_name,
        COUNT(l.loan_id)                        AS loans,
        IFNULL(SUM(l.status = 'ACTIVE'), 0)     AS active,
        IFNULL(SUM(l.principal), 0)             AS sanctioned,
        IFNULL(ROUND(AVG(l.interest_rate), 2), 0) AS avg_rate
FROM    branches b
LEFT JOIN loans l ON l.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name
ORDER BY sanctioned DESC;

-- Q6. Loan-type mix: types with an average ticket above Rs. 5 lakh
SELECT  loan_type,
        COUNT(*)                 AS loans,
        SUM(principal)           AS total_principal,
        ROUND(AVG(principal), 2) AS avg_ticket,
        MIN(interest_rate)       AS min_rate,
        MAX(interest_rate)       AS max_rate
FROM    loans
GROUP BY loan_type
HAVING  AVG(principal) > 500000
ORDER BY avg_ticket DESC;

-- Q7. High-value loans (>= Rs. 8 lakh) with no guarantor on record
SELECT  l.loan_id,
        c.full_name,
        b.branch_name,
        l.loan_type,
        l.principal
FROM    loans l
JOIN    customers c  ON c.customer_id = l.customer_id
JOIN    branches  b  ON b.branch_id   = l.branch_id
LEFT JOIN guarantors g ON g.loan_id   = l.loan_id
WHERE   l.principal >= 800000
  AND   g.guarantor_id IS NULL
ORDER BY l.principal DESC;

-- =====================================================================
-- 4. TASK 2 - CUSTOMERS WHOSE TOTAL EXPOSURE EXCEEDS THE BRANCH AVERAGE
--    Exposure = total principal of the customer's ACTIVE loans.
--    "Branch average" = average exposure of customers of the same
--    home branch.
-- =====================================================================

-- Q8(a). CORRELATED subquery: the inner query re-runs for every
--        customer and uses that customer's home_branch_id.
SELECT  c.customer_id,
        c.full_name,
        b.branch_name                          AS home_branch,
        (SELECT SUM(l.principal) FROM loans l
          WHERE l.customer_id = c.customer_id
            AND l.status = 'ACTIVE')           AS exposure
FROM    customers c
JOIN    branches  b ON b.branch_id = c.home_branch_id
WHERE   (SELECT SUM(l.principal) FROM loans l
          WHERE l.customer_id = c.customer_id
            AND l.status = 'ACTIVE')
      > (SELECT AVG(t.cust_total)
           FROM (SELECT c2.home_branch_id, SUM(l2.principal) AS cust_total
                   FROM customers c2
                   JOIN loans l2 ON l2.customer_id = c2.customer_id
                  WHERE l2.status = 'ACTIVE'
                  GROUP BY c2.customer_id, c2.home_branch_id) t
          WHERE t.home_branch_id = c.home_branch_id)
ORDER BY exposure DESC;

-- Q8(b). UNCORRELATED subqueries: the exposure per customer and the
--        branch averages are each computed once, then joined.
SELECT  e.customer_id,
        e.full_name,
        b.branch_name          AS home_branch,
        e.exposure,
        ROUND(ba.branch_avg, 2) AS branch_avg
FROM   (SELECT c.customer_id, c.full_name, c.home_branch_id,
               SUM(l.principal) AS exposure
          FROM customers c
          JOIN loans l ON l.customer_id = c.customer_id
         WHERE l.status = 'ACTIVE'
         GROUP BY c.customer_id, c.full_name, c.home_branch_id) e
JOIN   (SELECT home_branch_id, AVG(exposure) AS branch_avg
          FROM (SELECT c.customer_id, c.home_branch_id,
                       SUM(l.principal) AS exposure
                  FROM customers c
                  JOIN loans l ON l.customer_id = c.customer_id
                 WHERE l.status = 'ACTIVE'
                 GROUP BY c.customer_id, c.home_branch_id) x
         GROUP BY home_branch_id) ba
       ON ba.home_branch_id = e.home_branch_id
JOIN    branches b ON b.branch_id = e.home_branch_id
WHERE   e.exposure > ba.branch_avg
ORDER BY e.exposure DESC;

-- =====================================================================
-- 5. TASK 3 - EXISTS / NOT EXISTS
-- Q9. Customers with an active loan but no repayment in the last 60 days
-- =====================================================================
SELECT  c.customer_id,
        c.full_name,
        c.phone,
        (SELECT DATE_FORMAT(MAX(r.paid_on), '%d-%b-%Y')
           FROM repayments r JOIN loans l ON l.loan_id = r.loan_id
          WHERE l.customer_id = c.customer_id) AS last_payment
FROM    customers c
WHERE   EXISTS (SELECT 1
                  FROM loans l
                 WHERE l.customer_id = c.customer_id
                   AND l.status = 'ACTIVE')
  AND   NOT EXISTS (SELECT 1
                      FROM repayments r
                      JOIN loans l ON l.loan_id = r.loan_id
                     WHERE l.customer_id = c.customer_id
                       AND r.paid_on >= DATE_SUB(@report_date, INTERVAL 60 DAY))
ORDER BY c.customer_id;

-- =====================================================================
-- 6. TASK 4 - NESTED SUBQUERY
-- Q10. Branches whose highest loan is greater than the average of all
--      branch maximums
-- =====================================================================
SELECT  b.branch_id,
        b.branch_name,
        MAX(l.principal) AS highest_loan
FROM    branches b
JOIN    loans    l ON l.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name
HAVING  MAX(l.principal) > (SELECT AVG(bm.max_loan)
                              FROM (SELECT MAX(principal) AS max_loan
                                      FROM loans
                                     GROUP BY branch_id) bm)
ORDER BY highest_loan DESC;

-- Supporting check for Q10: the value the outer query compares against
SELECT  ROUND(AVG(bm.max_loan), 2) AS avg_of_branch_max
FROM   (SELECT MAX(principal) AS max_loan FROM loans GROUP BY branch_id) bm;
