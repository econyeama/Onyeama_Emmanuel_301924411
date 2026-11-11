-- =============================================================================
-- Portfolio 2 — queries/01_free_seats.sql
-- Q1. Free (unallocated) seats at a centre for a given session.
--
-- Business question: "A candidate wants to book session X — which computers
-- are still free?"
--
-- We pick the next upcoming Lagos PMP session as the example session and list
-- every active seat at that centre that has no row in seat_allocation for it.
-- =============================================================================

\echo ''
\echo '=== Q1. Free seats at a centre for a session ==='
\echo ''

-- Identify the example session (the next scheduled Lagos PMP session).
\echo '--- example session picked ---'
SELECT s.session_id,
       c.code AS centre, c.city,
       e.code AS exam,
       s.session_date, s.start_time
  FROM exam_session s
  JOIN centre c ON c.centre_id = s.centre_id
  JOIN exam   e ON e.exam_id   = s.exam_id
 WHERE c.code = 'LOS-01' AND e.code = 'PMP'
   AND s.session_date >= CURRENT_DATE
 ORDER BY s.session_date, s.start_time
 LIMIT 1;

\echo ''
\echo '--- query result: free seats for that session ---'
SELECT s.seat_id, s.seat_number, s.computer_name, s.status
  FROM seat s
  JOIN exam_session es ON es.centre_id = s.centre_id
 WHERE es.session_id = (
          SELECT session_id
            FROM exam_session s2
            JOIN centre c ON c.centre_id = s2.centre_id
            JOIN exam   e ON e.exam_id   = s2.exam_id
           WHERE c.code = 'LOS-01' AND e.code = 'PMP'
             AND s2.session_date >= CURRENT_DATE
           ORDER BY s2.session_date, s2.start_time
           LIMIT 1
       )
   AND s.status = 'active'
   AND NOT EXISTS (
         SELECT 1
           FROM seat_allocation sa
          WHERE sa.seat_id   = s.seat_id
            AND sa.session_id = es.session_id
       )
 ORDER BY s.seat_number
 LIMIT 20;

\echo ''
\echo '--- EXPLAIN ANALYZE (paste real output into results/before_after_table.md) ---'
EXPLAIN ANALYZE
SELECT s.seat_id, s.seat_number, s.computer_name
  FROM seat s
  JOIN exam_session es ON es.centre_id = s.centre_id
 WHERE es.session_id = (
          SELECT session_id
            FROM exam_session s2
            JOIN centre c ON c.centre_id = s2.centre_id
            JOIN exam   e ON e.exam_id   = s2.exam_id
           WHERE c.code = 'LOS-01' AND e.code = 'PMP'
             AND s2.session_date >= CURRENT_DATE
           ORDER BY s2.session_date, s2.start_time
           LIMIT 1
       )
   AND s.status = 'active'
   AND NOT EXISTS (
         SELECT 1 FROM seat_allocation sa
          WHERE sa.seat_id = s.seat_id
            AND sa.session_id = es.session_id
       );
