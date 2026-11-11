-- =============================================================================
-- Portfolio 2 — queries/02_candidates_per_exam_month.sql
-- Q2. Number of distinct candidates who sat each exam, grouped by month.
--
-- Business question: "Which exams are growing / shrinking month over month?"
-- =============================================================================

\echo ''
\echo '=== Q2. Candidates per exam per month ==='
\echo ''

SELECT e.code,
       e.title,
       to_char(date_trunc('month', es.session_date), 'YYYY-MM') AS month,
       count(DISTINCT sa.candidate_id)                            AS candidates
  FROM exam          e
  JOIN exam_session  es ON es.exam_id     = e.exam_id
  JOIN seat_allocation sa ON sa.session_id = es.session_id
 GROUP BY e.code, e.title, date_trunc('month', es.session_date)
 ORDER BY e.code, month
 LIMIT 40;

\echo ''
\echo '--- EXPLAIN ANALYZE ---'
EXPLAIN ANALYZE
SELECT e.code,
       to_char(date_trunc('month', es.session_date), 'YYYY-MM') AS month,
       count(DISTINCT sa.candidate_id) AS candidates
  FROM exam          e
  JOIN exam_session  es ON es.exam_id     = e.exam_id
  JOIN seat_allocation sa ON sa.session_id = es.session_id
 GROUP BY e.code, date_trunc('month', es.session_date)
 ORDER BY e.code, month;
