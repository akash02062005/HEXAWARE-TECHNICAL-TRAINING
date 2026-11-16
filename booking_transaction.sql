-- =====================================================================
-- Set 2 - Airline Seat Booking
-- File   : booking_transaction.sql
-- Author : AKASH S
-- Engine : MySQL 8.0 (InnoDB, REPEATABLE READ)
-- Purpose: schema, sample data, the atomic booking transaction
--          (SELECT ... FOR UPDATE) and the two-session locking test
-- =====================================================================

-- @block schema
DROP DATABASE IF EXISTS airline_booking;
CREATE DATABASE airline_booking;
USE airline_booking;

CREATE TABLE flights (
    flight_id      INT PRIMARY KEY,
    flight_no      VARCHAR(10)  NOT NULL UNIQUE,
    origin         CHAR(3)      NOT NULL,
    destination    CHAR(3)      NOT NULL,
    departure_time DATETIME     NOT NULL,
    aircraft       VARCHAR(20)  NOT NULL
) ENGINE = InnoDB;

CREATE TABLE seats (
    seat_id    INT PRIMARY KEY,
    flight_id  INT          NOT NULL,
    seat_no    VARCHAR(4)   NOT NULL,
    seat_class ENUM('BUSINESS','ECONOMY') NOT NULL,
    base_fare  DECIMAL(10,2) NOT NULL,
    status     ENUM('AVAILABLE','BOOKED') NOT NULL DEFAULT 'AVAILABLE',
    UNIQUE KEY uq_flight_seat (flight_id, seat_no),
    FOREIGN KEY (flight_id) REFERENCES flights (flight_id)
) ENGINE = InnoDB;

CREATE TABLE passengers (
    passenger_id INT PRIMARY KEY,
    full_name    VARCHAR(60) NOT NULL,
    email        VARCHAR(80) NOT NULL UNIQUE,
    phone        VARCHAR(15) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE bookings (
    booking_id   INT AUTO_INCREMENT PRIMARY KEY,
    flight_id    INT           NOT NULL,
    seat_id      INT           NOT NULL,
    passenger_id INT           NOT NULL,
    fare         DECIMAL(10,2) NOT NULL,
    booked_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_booking_seat (seat_id),          -- last line of defence
    FOREIGN KEY (flight_id)    REFERENCES flights (flight_id),
    FOREIGN KEY (seat_id)      REFERENCES seats (seat_id),
    FOREIGN KEY (passenger_id) REFERENCES passengers (passenger_id)
) ENGINE = InnoDB AUTO_INCREMENT = 9001;

-- @block data
INSERT INTO flights VALUES
 (1, 'SK101', 'BLR', 'DEL', '2026-11-20 06:10:00', 'Airbus A320neo'),
 (2, 'SK205', 'BLR', 'BOM', '2026-11-20 09:45:00', 'Boeing 737-8'),
 (3, 'SK318', 'MAA', 'CCU', '2026-11-21 14:30:00', 'Airbus A321neo');

INSERT INTO seats VALUES
 -- SK101 BLR-DEL
 (101, 1, '1A',  'BUSINESS', 18500, 'BOOKED'),
 (102, 1, '1C',  'BUSINESS', 18500, 'BOOKED'),
 (103, 1, '12A', 'ECONOMY',   9200, 'BOOKED'),
 (104, 1, '12B', 'ECONOMY',   7400, 'BOOKED'),
 (105, 1, '12C', 'ECONOMY',   7400, 'BOOKED'),
 (106, 1, '14A', 'ECONOMY',   6100, 'BOOKED'),
 (107, 1, '14B', 'ECONOMY',   6800, 'AVAILABLE'),
 (108, 1, '14C', 'ECONOMY',   6800, 'AVAILABLE'),
 (109, 1, '15A', 'ECONOMY',   6100, 'AVAILABLE'),
 -- SK205 BLR-BOM
 (201, 2, '1A',  'BUSINESS', 16800, 'BOOKED'),
 (202, 2, '12A', 'ECONOMY',   8900, 'BOOKED'),
 (203, 2, '12B', 'ECONOMY',   8900, 'BOOKED'),
 (204, 2, '12C', 'ECONOMY',   8900, 'BOOKED'),
 (205, 2, '14A', 'ECONOMY',   5600, 'BOOKED'),
 (206, 2, '14B', 'ECONOMY',   5900, 'AVAILABLE'),
 (207, 2, '14C', 'ECONOMY',   5900, 'AVAILABLE'),
 -- SK318 MAA-CCU
 (301, 3, '1A',  'BUSINESS', 21000, 'BOOKED'),
 (302, 3, '2A',  'BUSINESS', 11800, 'BOOKED'),
 (303, 3, '2C',  'BUSINESS', 11800, 'BOOKED'),
 (304, 3, '12A', 'ECONOMY',   7900, 'BOOKED'),
 (305, 3, '12B', 'ECONOMY',   6300, 'BOOKED'),
 (306, 3, '12C', 'ECONOMY',   6300, 'AVAILABLE');

INSERT INTO passengers VALUES
 (1,  'Arjun Rao',      'arjun.rao@mail.com',      '9845012345'),
 (2,  'Priya Nair',     'priya.nair@mail.com',     '9886023456'),
 (3,  'Rahul Sharma',   'rahul.sharma@mail.com',   '9820034567'),
 (4,  'Meera Iyer',     'meera.iyer@mail.com',     '9840045678'),
 (5,  'Suresh Patil',   'suresh.patil@mail.com',   '9822056789'),
 (6,  'Ananya Das',     'ananya.das@mail.com',     '9830067890'),
 (7,  'Vikram Singh',   'vikram.singh@mail.com',   '9810078901'),
 (8,  'Kavya Menon',    'kavya.menon@mail.com',    '9847089012'),
 (9,  'Rohit Kulkarni', 'rohit.k@mail.com',        '9823090123'),
 (10, 'Sneha Reddy',    'sneha.reddy@mail.com',    '9849101234'),
 (11, 'Imran Khan',     'imran.khan@mail.com',     '9866112345'),
 (12, 'Divya Pillai',   'divya.pillai@mail.com',   '9895123456'),
 (13, 'Karthik Raman',  'karthik.raman@mail.com',  '9884134567'),
 (14, 'Pooja Verma',    'pooja.verma@mail.com',    '9811145678'),
 (15, 'Nikhil Joshi',   'nikhil.joshi@mail.com',   '9890156789'),
 (16, 'Lakshmi Prasad', 'lakshmi.p@mail.com',      '9841167890');

INSERT INTO bookings (flight_id, seat_id, passenger_id, fare, booked_at) VALUES
 (1, 101, 1,  18500, '2026-11-02 10:15:00'),
 (1, 102, 7,  18500, '2026-11-03 18:40:00'),
 (1, 103, 2,   9200, '2026-11-05 09:05:00'),
 (1, 104, 4,   7400, '2026-11-08 21:30:00'),
 (1, 105, 10,  7400, '2026-11-09 07:55:00'),
 (1, 106, 13,  6100, '2026-11-12 16:20:00'),
 (2, 201, 3,  16800, '2026-11-01 11:00:00'),
 (2, 202, 6,   8900, '2026-11-04 13:45:00'),
 (2, 203, 11,  8900, '2026-11-06 08:10:00'),
 (2, 204, 12,  8900, '2026-11-06 08:12:00'),
 (2, 205, 15,  5600, '2026-11-10 22:05:00'),
 (3, 301, 5,  21000, '2026-11-02 15:30:00'),
 (3, 302, 1,  11800, '2026-11-07 12:00:00'),
 (3, 303, 14, 11800, '2026-11-07 12:01:00'),
 (3, 304, 16,  7900, '2026-11-11 19:25:00'),
 (3, 305, 2,   6300, '2026-11-13 06:50:00');

-- @block rowcheck
SELECT 'flights' AS table_name, COUNT(*) AS row_count FROM flights
UNION ALL SELECT 'seats',       COUNT(*) FROM seats
UNION ALL SELECT 'passengers',  COUNT(*) FROM passengers
UNION ALL SELECT 'bookings',    COUNT(*) FROM bookings;

-- =====================================================================
-- TASK 1 - The booking transaction
-- The seat row is locked with SELECT ... FOR UPDATE, then the booking
-- is inserted and the seat is marked BOOKED inside ONE transaction.
-- If the seat is already taken the transaction is rolled back.
-- =====================================================================

-- @block proc
DROP PROCEDURE IF EXISTS book_seat;
DELIMITER //
CREATE PROCEDURE book_seat(IN  p_flight_no    VARCHAR(10),
                           IN  p_seat_no      VARCHAR(4),
                           IN  p_passenger_id INT,
                           OUT p_result       VARCHAR(80))
BEGIN
    DECLARE v_seat_id   INT;
    DECLARE v_flight_id INT;
    DECLARE v_status    VARCHAR(10);
    DECLARE v_fare      DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = 'FAILED - error, transaction rolled back';
    END;

    START TRANSACTION;

    -- 1. lock the seat row; a second session waits here
    SELECT s.seat_id, s.flight_id, s.status, s.base_fare
      INTO v_seat_id, v_flight_id, v_status, v_fare
      FROM seats s
      JOIN flights f ON f.flight_id = s.flight_id
     WHERE f.flight_no = p_flight_no
       AND s.seat_no   = p_seat_no
       FOR UPDATE;

    IF v_seat_id IS NULL THEN
        ROLLBACK;
        SET p_result = 'FAILED - seat does not exist';
    ELSEIF v_status <> 'AVAILABLE' THEN
        ROLLBACK;
        SET p_result = CONCAT('FAILED - seat ', p_seat_no, ' is already booked');
    ELSE
        -- 2. record the booking
        INSERT INTO bookings (flight_id, seat_id, passenger_id, fare)
        VALUES (v_flight_id, v_seat_id, p_passenger_id, v_fare);

        -- 3. mark the seat as taken
        UPDATE seats SET status = 'BOOKED' WHERE seat_id = v_seat_id;

        COMMIT;
        SET p_result = CONCAT('CONFIRMED - booking ', LAST_INSERT_ID());
    END IF;
END //
DELIMITER ;

-- @block call1
CALL book_seat('SK205', '14B', 8, @r1);
CALL book_seat('SK205', '14B', 9, @r2);
SELECT @r1 AS first_attempt, @r2 AS second_attempt;

-- @block verify1
SELECT b.booking_id, f.flight_no, s.seat_no, s.status,
       p.full_name, b.fare
FROM   bookings b
JOIN   seats s      ON s.seat_id = b.seat_id
JOIN   flights f    ON f.flight_id = b.flight_id
JOIN   passengers p ON p.passenger_id = b.passenger_id
WHERE  f.flight_no = 'SK205' AND s.seat_no = '14B';

-- =====================================================================
-- TASK 2 - Two simultaneous bookings for seat 14C on SK101
-- Open two connections (two Workbench tabs) and run the steps in the
-- order shown by the step numbers.
-- =====================================================================

-- @block sessA1
-- SESSION A (Kavya Menon, passenger 8)
-- Step 1
START TRANSACTION;
SELECT seat_id, seat_no, status, base_fare
FROM   seats
WHERE  flight_id = 1 AND seat_no = '14C'
FOR UPDATE;

-- @block sessB1
-- SESSION B (Rohit Kulkarni, passenger 9)
-- Step 2  (this statement waits for Session A)
START TRANSACTION;
SELECT seat_id, seat_no, status, base_fare
FROM   seats
WHERE  flight_id = 1 AND seat_no = '14C'
FOR UPDATE;

-- @block monitor
-- Step 3  (any third connection, while Session B is waiting)
SELECT engine_transaction_id AS trx_id,
       object_name, index_name, lock_type,
       lock_mode, lock_status, lock_data
FROM   performance_schema.data_locks
WHERE  object_schema = 'airline_booking'
  AND  object_name   = 'seats'
ORDER  BY engine_transaction_id, lock_type, index_name;

-- @block sessA2
-- SESSION A
-- Step 4  (book the seat and release the lock)
INSERT INTO bookings (flight_id, seat_id, passenger_id, fare)
VALUES (1, 108, 8, 6800);
UPDATE seats SET status = 'BOOKED' WHERE seat_id = 108;
COMMIT;

-- @block sessB2
-- SESSION B
-- Step 5  (Session B's SELECT has now returned status = 'BOOKED',
--          so the application does not insert and rolls back)
ROLLBACK;

-- @block verify2
SELECT s.seat_no, s.status, b.booking_id, p.full_name, b.fare
FROM   seats s
LEFT JOIN bookings b   ON b.seat_id = s.seat_id
LEFT JOIN passengers p ON p.passenger_id = b.passenger_id
WHERE  s.flight_id = 1 AND s.seat_no = '14C';
