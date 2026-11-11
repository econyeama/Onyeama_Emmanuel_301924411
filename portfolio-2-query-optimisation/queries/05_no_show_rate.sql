-- =============================================================================
-- Portfolio 2 — queries/05_no_show_rate.sql
-- Q5. No-show rate per centre.
--
-- A "no-show" = a seat_allocation row where attended = false (the candidate
-- was booked and paid but did not sit the exam). Reported per centre so the
-- centre manager can see how many seats went unused on exam day.
-- =============================================================================

\echo ''
\echo '=== Q5. No-show rate per centre ==='
\echo ''

SELECT c.code,
       c.city,
       count(sa.allocation_id)                                 AS booked,
       count(*) FILTER (WHERE sa.attended = false)             AS no_shows,
       round(100.0
             * count(*) FILTER (WHERE sa.attended = false)
             / nullif(count(sa.allocation_id), 0), 2)         AS no_show_pct
  FROM seat_allocation sa
  JOIN exam_session   es ON es.session_id = sa.session_id
  JOIN centre         c  ON c.centre_id  = es.centre_id
 GROUP BY c.code, c.city
 ORDER BY no_show_pct DESC;

\echo ''
\echo '--- EXPLAIN ANALYZE ---'
EXPLAIN ANALYZE
SELECT c.code,
       count(*) FILTER (WHERE sa.attended = false)             AS no_shows,
       round(100.0
             * count(*) FILTER (WHERE sa.attended = false)
             / nullif(count(sa.allocation_id), 0), 2)         AS no_show_pct
  FROM seat_allocation sa
  JOIN exam_session   es ON es.session_id = sa.session_id
  JOIN centre         c  ON c.centre_id  = es.centre_id
 GROUP BY c.code
 ORDER BY no_show_pct DESC;
