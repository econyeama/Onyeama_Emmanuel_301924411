-- =============================================================================
-- Portfolio 2 — queries/09_candidate_history.sql
-- Q9. One candidate's exam history with scores and payment status.
--
-- Business question: "A candidate calls the help desk: show me every exam they
-- took, their score and whether they paid." This is a LOOKUP — it needs a few
-- rows out of ~100k results and ~130k payments, so it is where an index
-- should help most (result.candidate_id and payment.registration_id have no
-- index of their own before 02_indexes).
-- =============================================================================

\echo ''
\echo '=== Q9. One candidate''s exam history (help-desk lookup) ==='
\echo ''
-- the candidate with the most results, so the answer is never empty
SELECT candidate_id FROM result GROUP BY candidate_id ORDER BY count(*) DESC, candidate_id LIMIT 1 \gset

SELECT c.first_name || ' ' || c.last_name AS candidate, e.code AS exam, es.session_date,
       r.score, (r.score >= 50) AS passed, p.status AS payment
  FROM result r
  JOIN candidate c        ON c.candidate_id   = r.candidate_id
  JOIN exam e             ON e.exam_id        = r.exam_id
  JOIN seat_allocation sa ON sa.allocation_id = r.allocation_id
  JOIN exam_session es    ON es.session_id    = sa.session_id
  JOIN payment p          ON p.registration_id = sa.registration_id AND p.status = 'success'
 WHERE r.candidate_id = :candidate_id
 ORDER BY es.session_date DESC
 LIMIT 10;

\echo ''
\echo '--- EXPLAIN ANALYZE ---'
EXPLAIN ANALYZE
SELECT e.code, es.session_date, r.score, p.status
  FROM result r
  JOIN exam e             ON e.exam_id        = r.exam_id
  JOIN seat_allocation sa ON sa.allocation_id = r.allocation_id
  JOIN exam_session es    ON es.session_id    = sa.session_id
  JOIN payment p          ON p.registration_id = sa.registration_id AND p.status = 'success'
 WHERE r.candidate_id = :candidate_id;
