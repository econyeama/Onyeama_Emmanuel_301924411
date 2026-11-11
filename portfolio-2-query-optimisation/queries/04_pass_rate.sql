-- =============================================================================
-- Portfolio 2 — queries/04_pass_rate.sql
-- Q4. Pass rate per exam.
--
-- CBT convention: a score of 50 or above is a pass. The threshold is
-- parameterised in a CTE so it can be changed in one place.
-- =============================================================================

\echo ''
\echo '=== Q4. Pass rate per exam (pass mark = 50) ==='
\echo ''

WITH params AS (
    SELECT 50.0 AS pass_mark
)
SELECT e.code,
       e.title,
       count(r.result_id)                                      AS results_recorded,
       count(*) FILTER (WHERE r.score >= (SELECT pass_mark FROM params)) AS passes,
       count(*) FILTER (WHERE r.score  < (SELECT pass_mark FROM params)) AS fails,
       round(100.0
             * count(*) FILTER (WHERE r.score >= (SELECT pass_mark FROM params))
             / nullif(count(r.result_id), 0), 2)              AS pass_rate_pct,
       round(avg(r.score), 2)                                  AS avg_score
  FROM exam   e
  JOIN result r ON r.exam_id = e.exam_id
 GROUP BY e.code, e.title
 ORDER BY pass_rate_pct DESC;

\echo ''
\echo '--- EXPLAIN ANALYZE ---'
EXPLAIN ANALYZE
WITH params AS (SELECT 50.0 AS pass_mark)
SELECT e.code,
       count(*) FILTER (WHERE r.score >= (SELECT pass_mark FROM params)) AS passes,
       round(100.0
             * count(*) FILTER (WHERE r.score >= (SELECT pass_mark FROM params))
             / nullif(count(r.result_id), 0), 2) AS pass_rate_pct
  FROM exam   e
  JOIN result r ON r.exam_id = e.exam_id
 GROUP BY e.code
 ORDER BY pass_rate_pct DESC;
