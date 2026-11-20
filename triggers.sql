-- =====================================================================
-- Set 3 - Hospital Bed Capacity Control
-- File   : triggers.sql
-- Author : AKASH S
-- Date   : 20/11/2026
-- Target : MySQL 8.0 (InnoDB), run in MySQL Workbench
-- Content: schema, sample data, occupancy view and the five triggers
--          trg_admissions_bi_capacity  (Task 1 - BEFORE INSERT)
--          trg_admissions_bu_capacity  (same rule for ward transfers)
--          trg_admissions_ai_audit     (Task 2 - AFTER INSERT)
--          trg_admissions_au_audit     (Task 2 - AFTER UPDATE)
--          trg_admissions_ad_audit     (Task 2 - AFTER DELETE)
-- =====================================================================

DROP DATABASE IF EXISTS hospital_beds;
CREATE DATABASE hospital_beds;
USE hospital_beds;

-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------
CREATE TABLE wards (
    ward_id     INT          NOT NULL AUTO_INCREMENT,
    ward_code   VARCHAR(10)  NOT NULL,
    ward_name   VARCHAR(60)  NOT NULL,
    floor_no    TINYINT      NOT NULL,
    capacity    INT          NOT NULL,
    PRIMARY KEY (ward_id),
    UNIQUE KEY uq_ward_code (ward_code),
    CONSTRAINT chk_ward_capacity CHECK (capacity BETWEEN 1 AND 60)
) ENGINE = InnoDB;

CREATE TABLE patients (
    patient_id     INT          NOT NULL AUTO_INCREMENT,
    mrn            CHAR(9)      NOT NULL,
    full_name      VARCHAR(60)  NOT NULL,
    gender         CHAR(1)      NOT NULL,
    date_of_birth  DATE         NOT NULL,
    phone          CHAR(10)     NOT NULL,
    PRIMARY KEY (patient_id),
    UNIQUE KEY uq_patient_mrn (mrn),
    CONSTRAINT chk_patient_gender CHECK (gender IN ('M', 'F', 'O'))
) ENGINE = InnoDB;

CREATE TABLE admissions (
    admission_id      INT          NOT NULL AUTO_INCREMENT,
    patient_id        INT          NOT NULL,
    ward_id           INT          NOT NULL,
    admitting_doctor  VARCHAR(40)  NOT NULL,
    admitted_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    discharged_at     DATETIME     NULL,
    status            ENUM('ADMITTED', 'DISCHARGED') NOT NULL DEFAULT 'ADMITTED',
    PRIMARY KEY (admission_id),
    KEY idx_adm_ward_status (ward_id, status),
    CONSTRAINT fk_adm_patient FOREIGN KEY (patient_id) REFERENCES patients (patient_id),
    CONSTRAINT fk_adm_ward    FOREIGN KEY (ward_id)    REFERENCES wards (ward_id),
    -- row-level rule: a CHECK constraint is the right tool here (see Task 4)
    CONSTRAINT chk_adm_discharge CHECK (
        (status = 'ADMITTED'   AND discharged_at IS NULL) OR
        (status = 'DISCHARGED' AND discharged_at IS NOT NULL
                               AND discharged_at >= admitted_at))
) ENGINE = InnoDB AUTO_INCREMENT = 1001;

-- No foreign key to admissions: the history must survive a DELETE.
CREATE TABLE admission_audit (
    audit_id      BIGINT       NOT NULL AUTO_INCREMENT,
    admission_id  INT          NOT NULL,
    action_type   ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    patient_id    INT          NOT NULL,
    old_ward_id   INT          NULL,
    new_ward_id   INT          NULL,
    old_status    VARCHAR(10)  NULL,
    new_status    VARCHAR(10)  NULL,
    changed_by    VARCHAR(100) NOT NULL,
    changed_at    DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (audit_id),
    KEY idx_audit_admission (admission_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 2. Sample data (loaded before the triggers, so the audit starts empty)
-- ---------------------------------------------------------------------
INSERT INTO wards (ward_code, ward_name, floor_no, capacity) VALUES
('ICU-A', 'Intensive Care Unit A',  2, 4),
('GEN-M', 'General Ward - Male',    3, 6),
('GEN-F', 'General Ward - Female',  3, 6),
('PED',   'Paediatrics',            4, 5),
('MAT',   'Maternity',              4, 4),
('ISO',   'Isolation',              5, 2);

INSERT INTO patients (mrn, full_name, gender, date_of_birth, phone) VALUES
('MRN260101', 'Ramesh Iyer',        'M', '1958-03-14', '9840011201'),
('MRN260102', 'Sunita Rao',         'F', '1964-07-22', '9840011202'),
('MRN260103', 'Mohammed Siddiqui',  'M', '1971-01-09', '9840011203'),
('MRN260104', 'Kavya Nair',         'F', '1989-11-30', '9840011204'),
('MRN260105', 'Arvind Kumar',       'M', '1980-05-18', '9840011205'),
('MRN260106', 'Ganesh Pillai',      'M', '1967-09-02', '9840011206'),
('MRN260107', 'Joseph Mathew',      'M', '1975-12-11', '9840011207'),
('MRN260108', 'Harish Shetty',      'M', '1992-04-25', '9840011208'),
('MRN260109', 'Lakshmi Devi',       'F', '1955-08-19', '9840011209'),
('MRN260110', 'Ayesha Banu',        'F', '1983-02-07', '9840011210'),
('MRN260111', 'Revathi Krishnan',   'F', '1977-06-28', '9840011211'),
('MRN260112', 'Meenakshi Sundaram', 'F', '1961-10-15', '9840011212'),
('MRN260113', 'Divya Menon',        'F', '1995-01-23', '9840011213'),
('MRN260114', 'Aarav Sharma',       'M', '2019-09-12', '9840011214'),
('MRN260115', 'Ishita Gupta',       'F', '2021-03-04', '9840011215'),
('MRN260116', 'Priya Hegde',        'F', '1996-07-08', '9840011216'),
('MRN260117', 'Nandini Reddy',      'F', '1993-12-01', '9840011217'),
('MRN260118', 'Farzana Sheikh',     'F', '1998-05-16', '9840011218'),
('MRN260119', 'Pooja Kulkarni',     'F', '1994-09-27', '9840011219'),
('MRN260120', 'Vinod Chauhan',      'M', '1969-04-03', '9840011220'),
('MRN260121', 'Rekha Joshi',        'F', '1986-02-14', '9840011221'),
('MRN260122', 'Sanjay Patil',       'M', '1973-08-21', '9840011222'),
('MRN260123', 'Balaji Natarajan',   'M', '1960-11-05', '9840011223'),
('MRN260124', 'Fathima Rizwan',     'F', '1990-06-18', '9840011224'),
('MRN260125', 'Kiran Bhat',         'M', '1985-03-29', '9840011225'),
('MRN260126', 'Shalini Verma',      'F', '1979-10-10', '9840011226'),
('MRN260127', 'Rajesh Gowda',       'M', '1966-01-31', '9840011227'),
('MRN260128', 'Anil Deshpande',     'M', '1972-07-07', '9840011228'),
('MRN260129', 'Sameer Khan',        'M', '1988-12-19', '9840011229'),
('MRN260130', 'Usha Raman',         'F', '1959-05-26', '9840011230'),
('MRN260131', 'Tarun Malhotra',     'M', '1991-09-09', '9840011231'),
('MRN260132', 'Neha Saxena',        'F', '1997-02-02', '9840011232'),
('MRN260133', 'Deepak Agarwal',     'M', '1970-04-17', '9840011233'),
('MRN260134', 'Geetha Prakash',     'F', '1963-11-23', '9840011234');

-- 20 patients in a bed today (ICU-A 3/4, GEN-M 4/6, GEN-F 5/6, PED 2/5,
-- MAT 4/4 full, ISO 2/2 full) and 6 earlier stays that are discharged.
INSERT INTO admissions (patient_id, ward_id, admitting_doctor, admitted_at, discharged_at, status) VALUES
( 1, 1, 'Dr. S. Raghavan',  '2026-11-14 08:40:00', NULL, 'ADMITTED'),
( 2, 1, 'Dr. S. Raghavan',  '2026-11-16 22:15:00', NULL, 'ADMITTED'),
( 3, 1, 'Dr. A. Fernandes', '2026-11-18 03:05:00', NULL, 'ADMITTED'),
( 5, 2, 'Dr. M. Kapoor',    '2026-11-15 10:20:00', NULL, 'ADMITTED'),
( 6, 2, 'Dr. M. Kapoor',    '2026-11-17 14:45:00', NULL, 'ADMITTED'),
( 7, 2, 'Dr. P. Srinivas',  '2026-11-18 09:30:00', NULL, 'ADMITTED'),
( 8, 2, 'Dr. P. Srinivas',  '2026-11-19 16:10:00', NULL, 'ADMITTED'),
( 4, 3, 'Dr. L. Thomas',    '2026-11-13 11:00:00', NULL, 'ADMITTED'),
( 9, 3, 'Dr. L. Thomas',    '2026-11-16 07:55:00', NULL, 'ADMITTED'),
(10, 3, 'Dr. N. Bhatt',     '2026-11-17 19:25:00', NULL, 'ADMITTED'),
(11, 3, 'Dr. N. Bhatt',     '2026-11-18 13:40:00', NULL, 'ADMITTED'),
(12, 3, 'Dr. L. Thomas',    '2026-11-19 08:15:00', NULL, 'ADMITTED'),
(14, 4, 'Dr. K. Murthy',    '2026-11-18 12:30:00', NULL, 'ADMITTED'),
(15, 4, 'Dr. K. Murthy',    '2026-11-19 18:05:00', NULL, 'ADMITTED'),
(16, 5, 'Dr. R. Banerjee',  '2026-11-17 02:50:00', NULL, 'ADMITTED'),
(17, 5, 'Dr. R. Banerjee',  '2026-11-18 06:35:00', NULL, 'ADMITTED'),
(18, 5, 'Dr. V. Iyengar',   '2026-11-19 01:20:00', NULL, 'ADMITTED'),
(19, 5, 'Dr. V. Iyengar',   '2026-11-19 23:45:00', NULL, 'ADMITTED'),
(20, 6, 'Dr. H. Qadri',     '2026-11-16 15:00:00', NULL, 'ADMITTED'),
(21, 6, 'Dr. H. Qadri',     '2026-11-18 20:10:00', NULL, 'ADMITTED'),
(22, 1, 'Dr. S. Raghavan',  '2026-11-02 09:00:00', '2026-11-09 11:30:00', 'DISCHARGED'),
(23, 2, 'Dr. M. Kapoor',    '2026-11-04 13:15:00', '2026-11-08 10:00:00', 'DISCHARGED'),
(24, 3, 'Dr. N. Bhatt',     '2026-11-05 17:40:00', '2026-11-10 12:45:00', 'DISCHARGED'),
(25, 6, 'Dr. H. Qadri',     '2026-11-06 08:25:00', '2026-11-12 09:15:00', 'DISCHARGED'),
(26, 5, 'Dr. R. Banerjee',  '2026-11-07 04:10:00', '2026-11-10 16:30:00', 'DISCHARGED'),
(13, 3, 'Dr. L. Thomas',    '2026-11-08 10:50:00', '2026-11-11 15:20:00', 'DISCHARGED');

-- ---------------------------------------------------------------------
-- 3. Occupancy view used by the tests and the reports
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ward_occupancy AS
SELECT w.ward_id,
       w.ward_code,
       w.ward_name,
       w.capacity,
       COUNT(a.admission_id)              AS occupied_beds,
       w.capacity - COUNT(a.admission_id) AS free_beds,
       CASE WHEN COUNT(a.admission_id) >= w.capacity
            THEN 'FULL' ELSE 'OPEN' END   AS ward_state
FROM wards w
LEFT JOIN admissions a
       ON a.ward_id = w.ward_id
      AND a.status  = 'ADMITTED'
GROUP BY w.ward_id, w.ward_code, w.ward_name, w.capacity;

-- ---------------------------------------------------------------------
-- 4. Task 1 - BEFORE INSERT trigger that blocks admission to a full ward
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_admissions_bi_capacity;
DELIMITER //
CREATE TRIGGER trg_admissions_bi_capacity
BEFORE INSERT ON admissions
FOR EACH ROW
BEGIN
    DECLARE v_capacity  INT;
    DECLARE v_ward_code VARCHAR(10);
    DECLARE v_occupied  INT;
    DECLARE v_msg       VARCHAR(255);

    IF NEW.status = 'ADMITTED' THEN
        -- lock the ward row: two admissions to the same ward are serialised
        SELECT capacity, ward_code
          INTO v_capacity, v_ward_code
          FROM wards
         WHERE ward_id = NEW.ward_id
           FOR UPDATE;

        -- unknown ward: leave it to fk_adm_ward to reject the row
        IF v_capacity IS NOT NULL THEN
            SELECT COUNT(*)
              INTO v_occupied
              FROM admissions
             WHERE ward_id = NEW.ward_id
               AND status  = 'ADMITTED';

            IF v_occupied >= v_capacity THEN
                SET v_msg = CONCAT('Ward ', v_ward_code, ' is full (',
                                   v_occupied, '/', v_capacity,
                                   ' beds occupied). Admission of patient ',
                                   NEW.patient_id, ' blocked.');
                SIGNAL SQLSTATE '45000'
                   SET MESSAGE_TEXT = v_msg,
                       MYSQL_ERRNO  = 5001;
            END IF;
        END IF;
    END IF;
END //
DELIMITER ;

-- Same rule for an UPDATE that moves a patient into another ward
-- (or re-opens a discharged stay): otherwise a transfer could overfill it.
DROP TRIGGER IF EXISTS trg_admissions_bu_capacity;
DELIMITER //
CREATE TRIGGER trg_admissions_bu_capacity
BEFORE UPDATE ON admissions
FOR EACH ROW
BEGIN
    DECLARE v_capacity  INT;
    DECLARE v_ward_code VARCHAR(10);
    DECLARE v_occupied  INT;
    DECLARE v_msg       VARCHAR(255);

    IF NEW.status = 'ADMITTED'
       AND (NEW.ward_id <> OLD.ward_id OR OLD.status <> 'ADMITTED') THEN
        SELECT capacity, ward_code
          INTO v_capacity, v_ward_code
          FROM wards
         WHERE ward_id = NEW.ward_id
           FOR UPDATE;

        SELECT COUNT(*)
          INTO v_occupied
          FROM admissions
         WHERE ward_id = NEW.ward_id
           AND status  = 'ADMITTED';

        IF v_occupied >= v_capacity THEN
            SET v_msg = CONCAT('Ward ', v_ward_code, ' is full (',
                               v_occupied, '/', v_capacity,
                               ' beds occupied). Transfer of admission ',
                               OLD.admission_id, ' blocked.');
            SIGNAL SQLSTATE '45000'
               SET MESSAGE_TEXT = v_msg,
                   MYSQL_ERRNO  = 5002;
        END IF;
    END IF;
END //
DELIMITER ;

-- ---------------------------------------------------------------------
-- 5. Task 2 - AFTER INSERT / UPDATE / DELETE audit triggers
--    changed_by = application user set in @app_user, else the client login
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_admissions_ai_audit;
DELIMITER //
CREATE TRIGGER trg_admissions_ai_audit
AFTER INSERT ON admissions
FOR EACH ROW
BEGIN
    INSERT INTO admission_audit
        (admission_id, action_type, patient_id,
         old_ward_id, new_ward_id, old_status, new_status, changed_by)
    VALUES
        (NEW.admission_id, 'INSERT', NEW.patient_id,
         NULL, NEW.ward_id, NULL, NEW.status,
         COALESCE(@app_user, USER()));
END //
DELIMITER ;

DROP TRIGGER IF EXISTS trg_admissions_au_audit;
DELIMITER //
CREATE TRIGGER trg_admissions_au_audit
AFTER UPDATE ON admissions
FOR EACH ROW
BEGIN
    INSERT INTO admission_audit
        (admission_id, action_type, patient_id,
         old_ward_id, new_ward_id, old_status, new_status, changed_by)
    VALUES
        (NEW.admission_id, 'UPDATE', NEW.patient_id,
         OLD.ward_id, NEW.ward_id, OLD.status, NEW.status,
         COALESCE(@app_user, USER()));
END //
DELIMITER ;

DROP TRIGGER IF EXISTS trg_admissions_ad_audit;
DELIMITER //
CREATE TRIGGER trg_admissions_ad_audit
AFTER DELETE ON admissions
FOR EACH ROW
BEGIN
    INSERT INTO admission_audit
        (admission_id, action_type, patient_id,
         old_ward_id, new_ward_id, old_status, new_status, changed_by)
    VALUES
        (OLD.admission_id, 'DELETE', OLD.patient_id,
         OLD.ward_id, NULL, OLD.status, NULL,
         COALESCE(@app_user, USER()));
END //
DELIMITER ;

-- ---------------------------------------------------------------------
-- 6. Check: the five triggers on admissions
-- ---------------------------------------------------------------------
SELECT trigger_name, action_timing, event_manipulation, action_order
FROM information_schema.triggers
WHERE trigger_schema = 'hospital_beds'
ORDER BY event_manipulation, action_timing;
