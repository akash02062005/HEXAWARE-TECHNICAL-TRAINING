-- =====================================================================
--  Set 3 - Telecom Low-Balance Follow-up
--  File   : cursor.sql
--  Purpose: Task 4 - low-balance notifications with a cursor and a
--           NOT FOUND handler, the same with one INSERT ... SELECT,
--           and the execution-time comparison
--  Author : Akash S
--  Run after views.sql and procedures.sql
-- =====================================================================
USE telecom_followup;

-- ---------------------------------------------------------------------
-- 1. Cursor version: one INSERT per subscriber below the threshold
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_notify_low_balance_cursor;
DELIMITER //
CREATE PROCEDURE sp_notify_low_balance_cursor(IN  p_threshold DECIMAL(10,2),
                                              OUT p_rows      INT)
BEGIN
    DECLARE v_done    INT DEFAULT 0;
    DECLARE v_sub_id  INT;
    DECLARE v_msisdn  CHAR(10);
    DECLARE v_balance DECIMAL(10,2);

    DECLARE cur_low CURSOR FOR
        SELECT subscriber_id, msisdn, balance
          FROM vw_prepaid_subscribers
         WHERE status = 'ACTIVE'
           AND balance < p_threshold
         ORDER BY subscriber_id;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    SET p_rows = 0;
    OPEN cur_low;

    read_loop: LOOP
        FETCH cur_low INTO v_sub_id, v_msisdn, v_balance;
        IF v_done = 1 THEN
            LEAVE read_loop;
        END IF;

        INSERT INTO notifications
               (subscriber_id, msisdn, balance_at_notice, message, method)
        VALUES (v_sub_id, v_msisdn, v_balance,
                CONCAT('Low balance: Rs. ', v_balance,
                       ' left. Recharge now to stay connected.'),
                'CURSOR');
        SET p_rows = p_rows + 1;
    END LOOP;

    CLOSE cur_low;
END //
DELIMITER ;

CALL sp_notify_low_balance_cursor(50.00, @cursor_rows);
SELECT @cursor_rows AS rows_inserted;

SELECT notification_id, msisdn, balance_at_notice, message, method, created_at
  FROM notifications
 WHERE method = 'CURSOR'
 ORDER BY notification_id;

-- ---------------------------------------------------------------------
-- 2. Set-based version: the same rows with ONE INSERT ... SELECT
-- ---------------------------------------------------------------------
INSERT INTO notifications
       (subscriber_id, msisdn, balance_at_notice, message, method)
SELECT subscriber_id, msisdn, balance,
       CONCAT('Low balance: Rs. ', balance,
              ' left. Recharge now to stay connected.'),
       'SET_BASED'
  FROM vw_prepaid_subscribers
 WHERE status = 'ACTIVE'
   AND balance < 50.00
 ORDER BY subscriber_id;

-- both methods picked exactly the same subscribers
SELECT method, COUNT(*) AS rows_inserted,
       GROUP_CONCAT(subscriber_id ORDER BY subscriber_id) AS subscriber_ids
  FROM notifications
 GROUP BY method;

-- ---------------------------------------------------------------------
-- 3. Timing comparison on a larger load (50,000 extra subscribers)
-- ---------------------------------------------------------------------
SET SESSION cte_max_recursion_depth = 100000;

INSERT INTO subscribers
       (msisdn, full_name, plan_type, plan_id, balance, validity_end, status,
        circle, kyc_doc_ref, date_of_birth, home_address, email, credit_limit,
        activated_on)
WITH RECURSIVE seq (n) AS (
    SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 50000
)
SELECT CONCAT('70', LPAD(n, 8, '0')),
       CONCAT('Load Test User ', n),
       IF(n % 10 = 0, 'POSTPAID', 'PREPAID'),
       IF(n % 10 = 0, 6, 1 + (n % 4)),
       ROUND(((n * 7919) % 50000) / 100, 2),
       CURDATE() + INTERVAL (n % 60) DAY,
       'ACTIVE', 'Karnataka', CONCAT('KYC-LT-', n), '1995-01-01',
       'Load test address', NULL, NULL, '2025-01-01'
  FROM seq;

CREATE TABLE IF NOT EXISTS notification_timing (
    run_no        INT          NOT NULL,
    method        VARCHAR(10)  NOT NULL,
    rows_inserted INT          NOT NULL,
    elapsed_ms    DECIMAL(10,3) NOT NULL,
    PRIMARY KEY (run_no, method)
) ENGINE = InnoDB;
TRUNCATE TABLE notification_timing;

DROP PROCEDURE IF EXISTS sp_time_notifications;
DELIMITER //
CREATE PROCEDURE sp_time_notifications(IN p_runs INT)
BEGIN
    DECLARE v_run  INT DEFAULT 1;
    DECLARE v_mark INT;
    DECLARE v_rows INT;
    DECLARE v_t0   DATETIME(6);

    SELECT COALESCE(MAX(notification_id), 0) INTO v_mark FROM notifications;

    WHILE v_run <= p_runs DO
        -- cursor method
        SET v_t0 = NOW(6);
        CALL sp_notify_low_balance_cursor(50.00, v_rows);
        INSERT INTO notification_timing
        VALUES (v_run, 'CURSOR', v_rows,
                TIMESTAMPDIFF(MICROSECOND, v_t0, NOW(6)) / 1000);
        DELETE FROM notifications WHERE notification_id > v_mark;

        -- set-based method
        SET v_t0 = NOW(6);
        INSERT INTO notifications
               (subscriber_id, msisdn, balance_at_notice, message, method)
        SELECT subscriber_id, msisdn, balance,
               CONCAT('Low balance: Rs. ', balance,
                      ' left. Recharge now to stay connected.'),
               'SET_BASED'
          FROM vw_prepaid_subscribers
         WHERE status = 'ACTIVE' AND balance < 50.00
         ORDER BY subscriber_id;
        SET v_rows = ROW_COUNT();
        INSERT INTO notification_timing
        VALUES (v_run, 'SET_BASED', v_rows,
                TIMESTAMPDIFF(MICROSECOND, v_t0, NOW(6)) / 1000);
        DELETE FROM notifications WHERE notification_id > v_mark;

        SET v_run = v_run + 1;
    END WHILE;
END //
DELIMITER ;

CALL sp_time_notifications(3);

SELECT * FROM notification_timing ORDER BY run_no, method;

SELECT method,
       COUNT(*)                  AS runs,
       MAX(rows_inserted)        AS rows_per_run,
       ROUND(MIN(elapsed_ms), 1) AS min_ms,
       ROUND(AVG(elapsed_ms), 1) AS avg_ms,
       ROUND(MAX(elapsed_ms), 1) AS max_ms,
       ROUND(AVG(elapsed_ms) / MIN(AVG(elapsed_ms)) OVER (), 1) AS relative_time
  FROM notification_timing
 GROUP BY method
 ORDER BY avg_ms DESC;

-- remove the load-test rows, keep the sample data
DELETE FROM subscribers WHERE msisdn LIKE '70%';
