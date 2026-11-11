-- =============================================================================
-- Portfolio 2 — queries/07_top_exams_by_revenue.sql
-- Q7 (bonus). Top 10 exams by total successful-payment revenue.
--
-- Helps TestPoint decide which exam bodies to prioritise in marketing and
-- which centres to keep open for them.
-- =============================================================================

\echo ''
\echo '=== Q7. Top exams by revenue (NGN, successful payments) ==='
\echo ''

SELECT e.code,
       e.title,
       e.category,
       count(p.payment_id)                       AS successful_payments,
       to_char(sum(p.amount), 'FM999,999,999')   AS revenue_ngn
  FROM exam           e
  JOIN exam_session   es ON es.exam_id     = e.exam_id
  JOIN seat_allocation sa ON sa.session_id = es.session_id
  JOIN registration    r ON r.registration_id = sa.registration_id
  JOIN payment         p ON p.registration_id = r.registration_id
 WHERE p.status = 'success'
 GROUP BY e.code, e.title, e.category
 ORDER BY sum(p.amount) DESC
 LIMIT 10;

\echo ''
\echo '--- EXPLAIN ANALYZE ---'
EXPLAIN ANALYZE
SELECT e.code,
       sum(p.amount) AS revenue_ngn
  FROM exam           e
  JOIN exam_session   es ON es.exam_id     = e.exam_id
  JOIN seat_allocation sa ON sa.session_id = es.session_id
  JOIN registration    r ON r.registration_id = sa.registration_id
  JOIN payment         p ON p.registration_id = r.registration_id
 WHERE p.status = 'success'
 GROUP BY e.code
 ORDER BY sum(p.amount) DESC
 LIMIT 10;
