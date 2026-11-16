-- =====================================================================
-- Set 2 - Airline Seat Booking
-- File   : ranking_report.sql
-- Author : AKASH S
-- Engine : MySQL 8.0
-- Run booking_transaction.sql first (schema, data and bookings).
-- =====================================================================
USE airline_booking;

-- =====================================================================
-- TASK 3 - Passengers ranked by fare within each flight
-- RANK() leaves gaps after a tie, DENSE_RANK() does not.
-- =====================================================================
-- @block rank
SELECT f.flight_no,
       p.full_name,
       s.seat_no,
       b.fare,
       RANK()       OVER (PARTITION BY b.flight_id ORDER BY b.fare DESC) AS fare_rank,
       DENSE_RANK() OVER (PARTITION BY b.flight_id ORDER BY b.fare DESC) AS fare_dense_rank
FROM   bookings b
JOIN   flights f    ON f.flight_id    = b.flight_id
JOIN   passengers p ON p.passenger_id = b.passenger_id
JOIN   seats s      ON s.seat_id      = b.seat_id
ORDER  BY f.flight_no, b.fare DESC, p.full_name;

-- =====================================================================
-- TASK 4 - Same report as a CTE with a running total of revenue
-- ROWS BETWEEN ... makes tied fares add up one row at a time.
-- =====================================================================
-- @block cte
WITH flight_bookings AS (
    SELECT b.booking_id, b.flight_id, f.flight_no,
           p.full_name, s.seat_no, b.fare
    FROM   bookings b
    JOIN   flights f    ON f.flight_id    = b.flight_id
    JOIN   passengers p ON p.passenger_id = b.passenger_id
    JOIN   seats s      ON s.seat_id      = b.seat_id
),
ranked AS (
    SELECT fb.*,
           RANK()       OVER w AS fare_rank,
           DENSE_RANK() OVER w AS fare_dense_rank,
           SUM(fb.fare) OVER (PARTITION BY fb.flight_id
                              ORDER BY fb.fare DESC, fb.booking_id
                              ROWS BETWEEN UNBOUNDED PRECEDING
                                       AND CURRENT ROW) AS running_revenue
    FROM   flight_bookings fb
    WINDOW w AS (PARTITION BY fb.flight_id ORDER BY fb.fare DESC)
)
SELECT flight_no, full_name, seat_no, fare,
       fare_rank, fare_dense_rank, running_revenue
FROM   ranked
ORDER  BY flight_no, fare DESC, booking_id;

-- =====================================================================
-- TASK 5 - Passengers whose fare is above their flight's average
-- The inner query is correlated: it uses b.flight_id of the outer row.
-- =====================================================================
-- @block corr
SELECT f.flight_no,
       p.full_name,
       b.fare,
       (SELECT ROUND(AVG(b2.fare), 2)
          FROM bookings b2
         WHERE b2.flight_id = b.flight_id) AS flight_avg_fare
FROM   bookings b
JOIN   flights f    ON f.flight_id    = b.flight_id
JOIN   passengers p ON p.passenger_id = b.passenger_id
WHERE  b.fare > (SELECT AVG(b2.fare)
                   FROM bookings b2
                  WHERE b2.flight_id = b.flight_id)
ORDER  BY f.flight_no, b.fare DESC;
