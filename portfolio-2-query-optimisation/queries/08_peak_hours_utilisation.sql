-- =============================================================================
-- Portfolio 2 — queries/08_peak_hours_utilisation.sql
-- Q8 (bonus). Utilisation by hour-of-day across all centres.
--
-- Shows the exam-day "peak hour" pattern (morning vs afternoon vs evening
-- sessions) so TestPoint can plan staffing and decide whether to open a
-- second morning slot in high-demand centres.
-- =============================================================================

\echo ''
\echo '=== Q8. Allocations by start-hour (peak-hours analysis) ==='
\echo ''

SELECT extract(hour FROM es.start_time)::int AS start_hour,
       count(DISTINCT es.session_id)         AS sessions,
       count(sa.allocation_id)               AS allocations,
       round(avg(c.seat_capacity), 1)        AS avg_centre_capacity
  FROM exam_session    es
  JOIN centre          c  ON c.centre_id  = es.centre_id
  LEFT JOIN seat_allocation sa ON sa.session_id = es.session_id
 GROUP BY start_hour
 ORDER BY start_hour;

\echo ''
\echo '--- EXPLAIN ANALYZE ---'
EXPLAIN ANALYZE
SELECT extract(hour FROM es.start_time)::int AS start_hour,
       count(DISTINCT es.session_id)         AS sessions,
       count(sa.allocation_id)               AS allocations
  FROM exam_session    es
  LEFT JOIN seat_allocation sa ON sa.session_id = es.session_id
 GROUP BY start_hour
 ORDER BY start_hour;
