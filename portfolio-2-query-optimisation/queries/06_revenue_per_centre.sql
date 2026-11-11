-- =============================================================================
-- Portfolio 2 — queries/06_revenue_per_centre.sql
-- Q6. Total successful-payment revenue per centre (in NGN).
--
-- Revenue is attributed to the centre where the candidate actually sat, so
-- the join path is:
--   centre → exam_session → seat_allocation → registration → payment
-- and we only sum rows where payment.status = 'success'.
-- =============================================================================

\echo ''
\echo '=== Q6. Revenue per centre (NGN, successful payments only) ==='
\echo ''

SELECT c.code,
       c.city,
       count(p.payment_id)                       AS successful_payments,
       to_char(sum(p.amount), 'FM999,999,999')   AS revenue_ngn
  FROM centre         c
  JOIN exam_session   es ON es.centre_id   = c.centre_id
  JOIN seat_allocation sa ON sa.session_id = es.session_id
  JOIN registration    r ON r.registration_id = sa.registration_id
  JOIN payment         p ON p.registration_id = r.registration_id
 WHERE p.status = 'success'
 GROUP BY c.code, c.city
 ORDER BY sum(p.amount) DESC;

\echo ''
\echo '--- EXPLAIN ANALYZE ---'
EXPLAIN ANALYZE
SELECT c.code,
       sum(p.amount) AS revenue_ngn
  FROM centre         c
  JOIN exam_session   es ON es.centre_id   = c.centre_id
  JOIN seat_allocation sa ON sa.session_id = es.session_id
  JOIN registration    r ON r.registration_id = sa.registration_id
  JOIN payment         p ON p.registration_id = r.registration_id
 WHERE p.status = 'success'
 GROUP BY c.code
 ORDER BY sum(p.amount) DESC;
