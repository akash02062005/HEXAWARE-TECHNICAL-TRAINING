-- =====================================================================
--  Set 3 - Telecom Low-Balance Follow-up
--  File   : procedures.sql
--  Purpose: sp_recharge (Task 2), fn_validity_days_left (Task 3) and
--           error handling with HANDLER FOR SQLEXCEPTION + SIGNAL (Task 5)
--  Author : Akash S
--  Run after views.sql
-- =====================================================================
USE telecom_followup;

-- ---------------------------------------------------------------------
-- Task 2 - sp_recharge
--   * validates the amount and the plan
--   * locks the subscriber row, updates the balance and inserts the
--     recharge history row in ONE transaction
--   * returns the new balance through the OUT parameter
--   * any error -> handler rolls back, logs it and raises it again
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_recharge;
DELIMITER //
CREATE PROCEDURE sp_recharge(IN  p_msisdn      CHAR(10),
                             IN  p_plan_code   VARCHAR(10),
                             IN  p_amount      DECIMAL(8,2),
                             OUT p_new_balance DECIMAL(10,2))
BEGIN
    DECLARE v_sub_id     INT;
    DECLARE v_sub_type   VARCHAR(10);
    DECLARE v_sub_status VARCHAR(10);
    DECLARE v_balance    DECIMAL(10,2);
    DECLARE v_plan_id    INT;
    DECLARE v_plan_type  VARCHAR(10);
    DECLARE v_price      DECIMAL(8,2);
    DECLARE v_days       INT;
    DECLARE v_active     TINYINT;
    DECLARE v_state      CHAR(5);
    DECLARE v_errno      INT;
    DECLARE v_msg        VARCHAR(255);
    DECLARE v_out        VARCHAR(128);

    -- Task 5: one handler for every SQL error raised in this procedure
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_state = RETURNED_SQLSTATE,
            v_errno = MYSQL_ERRNO,
            v_msg   = MESSAGE_TEXT;
        ROLLBACK;
        SET p_new_balance = NULL;
        INSERT INTO recharge_error_log
               (msisdn, plan_code, amount, sql_state, error_no, error_message)
        VALUES (p_msisdn, p_plan_code, p_amount, v_state, v_errno, v_msg);
        SET v_out = CONCAT('Recharge rejected: ', LEFT(v_msg, 100));
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_out;
    END;

    -- 1. validate the amount
    IF p_amount IS NULL OR p_amount <= 0 OR p_amount > 5000 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid amount: must be between 1 and 5000';
    END IF;

    -- 2. validate the plan
    SELECT plan_id, plan_type, price, validity_days, is_active
      INTO v_plan_id, v_plan_type, v_price, v_days, v_active
      FROM plans
     WHERE plan_code = p_plan_code;

    IF v_plan_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown plan code';
    ELSEIF v_active = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Plan is no longer active';
    ELSEIF v_plan_type <> 'PREPAID' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Plan is not a prepaid plan';
    ELSEIF p_amount <> v_price THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount does not match the plan price';
    END IF;

    -- 3. transactional update
    START TRANSACTION;

    SELECT subscriber_id, plan_type, status, balance
      INTO v_sub_id, v_sub_type, v_sub_status, v_balance
      FROM subscribers
     WHERE msisdn = p_msisdn
       FOR UPDATE;

    IF v_sub_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subscriber not found';
    ELSEIF v_sub_type <> 'PREPAID' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subscriber is not prepaid';
    ELSEIF v_sub_status <> 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subscriber is suspended';
    END IF;

    UPDATE subscribers
       SET balance      = balance + p_amount,
           plan_id      = v_plan_id,
           validity_end = GREATEST(COALESCE(validity_end, CURDATE()), CURDATE())
                          + INTERVAL v_days DAY
     WHERE subscriber_id = v_sub_id;

    INSERT INTO recharges
           (subscriber_id, plan_id, amount, balance_before, balance_after, channel)
    VALUES (v_sub_id, v_plan_id, p_amount, v_balance, v_balance + p_amount, 'APP');

    COMMIT;

    SET p_new_balance = v_balance + p_amount;
END //
DELIMITER ;

-- Task 2 - test: valid recharges, new balance returned in the OUT parameter
CALL sp_recharge('9845012302', 'PR199', 199.00, @bal_divya);
CALL sp_recharge('9845012303', 'PR099',  99.00, @bal_karthik);
SELECT @bal_divya AS divya_new_balance, @bal_karthik AS karthik_new_balance;

SELECT r.recharge_id, s.msisdn, s.full_name, p.plan_code, r.amount,
       r.balance_before, r.balance_after, s.validity_end, r.recharged_at
  FROM recharges r
  JOIN subscribers s ON s.subscriber_id = r.subscriber_id
  JOIN plans p       ON p.plan_id       = r.plan_id
 WHERE r.recharge_id > 5015
 ORDER BY r.recharge_id;

-- ---------------------------------------------------------------------
-- Task 3 - fn_validity_days_left
--   days from today to validity_end; 0 once the validity has ended,
--   NULL for postpaid rows that have no validity date
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_validity_days_left;
DELIMITER //
CREATE FUNCTION fn_validity_days_left(p_validity_end DATE)
RETURNS INT
NOT DETERMINISTIC
NO SQL
BEGIN
    IF p_validity_end IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN GREATEST(DATEDIFF(p_validity_end, CURDATE()), 0);
END //
DELIMITER ;

-- function used in a query: low-balance prepaid users ordered by urgency
SELECT msisdn, full_name, plan_code, balance, validity_end, days_left,
       CASE
           WHEN validity_end < CURDATE() THEN 'EXPIRED'
           WHEN days_left <= 3           THEN 'EXPIRING SOON'
           WHEN days_left <= 7           THEN 'THIS WEEK'
           ELSE 'OK'
       END AS validity_flag
  FROM (SELECT v.*, fn_validity_days_left(v.validity_end) AS days_left
          FROM vw_prepaid_subscribers v
         WHERE v.status = 'ACTIVE') t
 ORDER BY days_left, balance;

-- ---------------------------------------------------------------------
-- Task 5 - errors caught by DECLARE EXIT HANDLER FOR SQLEXCEPTION,
--          raised with SIGNAL
-- ---------------------------------------------------------------------
SET @new_balance = NULL;
CALL sp_recharge('9845012310', 'PR299', -50.00, @new_balance);  -- bad amount
CALL sp_recharge('9845012310', 'PR555', 555.00, @new_balance);  -- inactive plan
CALL sp_recharge('9845012315', 'PR199', 199.00, @new_balance);  -- postpaid user

SELECT error_id, msisdn, plan_code, amount, sql_state, error_no,
       error_message, logged_at
  FROM recharge_error_log
 ORDER BY error_id;

-- nothing was changed by the failed calls
SELECT msisdn, full_name, balance, @new_balance AS out_param
  FROM subscribers
 WHERE msisdn IN ('9845012310', '9845012315');
