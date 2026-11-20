-- =====================================================================
-- Set 3 - Hospital Bed Capacity Control
-- File   : test_evidence.sql
-- Author : AKASH S
-- Date   : 20/11/2026
-- Run after triggers.sql, in one session, top to bottom. Statements that
-- are expected to fail are marked "EXPECTED ERROR"; in MySQL Workbench
-- untick "Stop Script Execution on Errors" or run them one at a time.
-- =====================================================================
USE hospital_beds;

-- Starting state: ICU-A has 1 free bed, MAT and ISO are already full
SELECT * FROM vw_ward_occupancy;

-- ---------------------------------------------------------------------
-- TASK 1 - BEFORE INSERT trigger blocks admissions to a full ward
-- ---------------------------------------------------------------------
-- 1.1 last free ICU-A bed: allowed, ICU-A becomes 4/4
INSERT INTO admissions (patient_id, ward_id, admitting_doctor)
VALUES (27, 1, 'Dr. S. Raghavan');

-- 1.2 ICU-A is now full (occupied = capacity)        EXPECTED ERROR 5001
INSERT INTO admissions (patient_id, ward_id, admitting_doctor)
VALUES (28, 1, 'Dr. A. Fernandes');

-- 1.3 ISO was full from the start                      EXPECTED ERROR 5001
INSERT INTO admissions (patient_id, ward_id, admitting_doctor)
VALUES (29, 6, 'Dr. H. Qadri');

-- 1.4 a past, already discharged stay may still be recorded in a full ward
INSERT INTO admissions (patient_id, ward_id, admitting_doctor,
                        admitted_at, discharged_at, status)
VALUES (30, 6, 'Dr. H. Qadri', '2026-10-21 09:10:00',
        '2026-10-27 12:00:00', 'DISCHARGED');

-- 1.5 transfer into a full ward is blocked as well      EXPECTED ERROR 5002
UPDATE admissions SET ward_id = 6 WHERE admission_id = 1004;

-- Evidence for Task 1
SELECT admission_id, patient_id, ward_id, admitted_at, discharged_at, status
FROM admissions
WHERE patient_id IN (27, 28, 29, 30)
ORDER BY admission_id;

SELECT * FROM vw_ward_occupancy;

-- ---------------------------------------------------------------------
-- TASK 2 - every admission change is written to admission_audit
-- ---------------------------------------------------------------------
-- 2.1 step-down: patient 3 moves from ICU-A to GEN-M (frees an ICU bed)
UPDATE admissions SET ward_id = 2 WHERE admission_id = 1003;

-- 2.2 discharge made through the application user 'nurse.kavitha'
SET @app_user = 'nurse.kavitha';
UPDATE admissions
   SET status = 'DISCHARGED', discharged_at = '2026-11-20 11:30:00'
 WHERE admission_id = 1009;
SET @app_user = NULL;

-- 2.3 admission created for the wrong patient, then deleted
INSERT INTO admissions (patient_id, ward_id, admitting_doctor)
VALUES (31, 2, 'Dr. M. Kapoor');
DELETE FROM admissions WHERE admission_id = LAST_INSERT_ID();

-- Evidence for Task 2: one audit row per successful change, none for the
-- three statements that the capacity triggers rejected
SELECT * FROM admission_audit ORDER BY audit_id;

SELECT a.audit_id, a.admission_id, a.action_type,
       ow.ward_code AS from_ward, nw.ward_code AS to_ward,
       a.old_status, a.new_status, a.changed_by
FROM admission_audit a
LEFT JOIN wards ow ON ow.ward_id = a.old_ward_id
LEFT JOIN wards nw ON nw.ward_id = a.new_ward_id
ORDER BY a.audit_id;

-- ---------------------------------------------------------------------
-- TASK 3 - multi-row INSERT in which one row exceeds capacity
-- ---------------------------------------------------------------------
SET SESSION information_schema_stats_expiry = 0;

-- Before: ICU-A 3/4 after the step-down, GEN-F 4/6 after the discharge
SELECT ward_code, capacity, occupied_beds, free_beds
FROM vw_ward_occupancy WHERE ward_code IN ('ICU-A', 'GEN-F');

SELECT (SELECT COUNT(*) FROM admissions)      AS admission_rows,
       (SELECT COUNT(*) FROM admission_audit) AS audit_rows,
       (SELECT auto_increment FROM information_schema.tables
         WHERE table_schema = 'hospital_beds'
           AND table_name   = 'admissions')   AS next_admission_id;

-- 3.1 row 1 takes the last ICU-A bed, row 2 is fine, row 3 overflows ICU-A
--                                                       EXPECTED ERROR 5001
INSERT INTO admissions (patient_id, ward_id, admitting_doctor) VALUES
(28, 1, 'Dr. A. Fernandes'),
(32, 3, 'Dr. N. Bhatt'),
(33, 1, 'Dr. S. Raghavan');

-- After: nothing from the statement is left, not even rows 1 and 2 or
-- their audit rows; only the AUTO_INCREMENT values are used up
SELECT * FROM admissions WHERE patient_id IN (28, 32, 33);

SELECT (SELECT COUNT(*) FROM admissions)      AS admission_rows,
       (SELECT COUNT(*) FROM admission_audit) AS audit_rows,
       (SELECT auto_increment FROM information_schema.tables
         WHERE table_schema = 'hospital_beds'
           AND table_name   = 'admissions')   AS next_admission_id;

-- 3.2 inside an explicit transaction only the failing statement is undone
START TRANSACTION;
INSERT INTO admissions (patient_id, ward_id, admitting_doctor)
VALUES (34, 3, 'Dr. L. Thomas');
--                                                       EXPECTED ERROR 5001
INSERT INTO admissions (patient_id, ward_id, admitting_doctor) VALUES
(28, 1, 'Dr. A. Fernandes'),
(33, 1, 'Dr. S. Raghavan');
SELECT admission_id, patient_id, ward_id, status
FROM admissions WHERE patient_id IN (34, 28, 33);
ROLLBACK;

-- 3.3 the corrected batch (one ICU-A row only) goes through as a whole
INSERT INTO admissions (patient_id, ward_id, admitting_doctor) VALUES
(28, 1, 'Dr. A. Fernandes'),
(32, 3, 'Dr. N. Bhatt');

SELECT admission_id, patient_id, ward_id, admitted_at, status
FROM admissions WHERE patient_id IN (28, 32, 33, 34);

SELECT * FROM vw_ward_occupancy;

-- ---------------------------------------------------------------------
-- TASK 4 - where a CHECK constraint fits and where it cannot be used
-- ---------------------------------------------------------------------
-- 4.1 row-level rule enforced by chk_adm_discharge     EXPECTED ERROR 3819
UPDATE admissions SET status = 'DISCHARGED' WHERE admission_id = 1010;

-- 4.2 a CHECK cannot look at other rows or tables      EXPECTED ERROR 3815
ALTER TABLE wards ADD CONSTRAINT chk_ward_not_full CHECK (
    capacity >= (SELECT COUNT(*) FROM admissions a
                 WHERE a.ward_id = wards.ward_id AND a.status = 'ADMITTED'));

-- ---------------------------------------------------------------------
-- Final summary
-- ---------------------------------------------------------------------
SELECT action_type, COUNT(*) AS audit_rows
FROM admission_audit
GROUP BY action_type
ORDER BY action_type;
