-- =============================================================================
-- Portfolio 2 — queries/03_centre_utilisation.sql
-- Q3. Centre utilisation % — allocations vs total seat-session capacity.
--
-- For each centre:
--   numerator   = count of seat_allocation rows
--   denominator = (centre.seat_capacity) × (number of sessions at that centre)
--   utilisation = 100 * num / denom
--
-- The LEFT JOIN to seat_allocation keeps centres with zero allocations
-- (so they show 0 %, not a missing row).
-- =============================================================================

\echo ''
\echo '=== Q3. Centre utilisation % ==='
\echo ''

SELECT c.code,
       c.city,
       count(DISTINCT es.session_id)                            AS sessions_held,
       c.seat_capacity * count(DISTINCT es.session_id)          AS seat_session_capacity,
       count(sa.allocation_id)                                  AS allocations,
       round(100.0 * count(sa.allocation_id)
             / nullif(c.seat_capacity * count(DISTINCT es.session_id), 0), 2)
                                                               AS utilisation_pct
  FROM centre         c
  JOIN exam_session   es ON es.centre_id  = c.centre_id
  LEFT JOIN seat_allocation sa ON sa.session_id = es.session_id
 GROUP BY c.code, c.city, c.seat_capacity
 ORDER BY utilisation_pct DESC;

\echo ''
\echo '--- EXPLAIN ANALYZE ---'
EXPLAIN ANALYZE
SELECT c.code,
       c.seat_capacity * count(DISTINCT es.session_id)          AS seat_session_capacity,
       count(sa.allocation_id)                                  AS allocations,
       round(100.0 * count(sa.allocation_id)
             / nullif(c.seat_capacity * count(DISTINCT es.session_id), 0), 2)
                                                               AS utilisation_pct
  FROM centre         c
  JOIN exam_session   es ON es.centre_id  = c.centre_id
  LEFT JOIN seat_allocation sa ON sa.session_id = es.session_id
 GROUP BY c.code, c.seat_capacity
 ORDER BY utilisation_pct DESC;
