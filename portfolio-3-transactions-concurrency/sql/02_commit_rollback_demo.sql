-- =============================================================================
-- Portfolio 3 — sql/02_commit_rollback_demo.sql
-- allocate_seat() is atomic: registration + seat_allocation + payment are
-- written together or not at all.
--   DEMO A  valid payment              → COMMIT, 3 new rows
--   DEMO B  payment ₦0                 → ERROR → ROLLBACK, 0 new rows, seat still free
--   DEMO C  same candidate, same seat, valid payment → COMMIT (seat was released)
-- The demo rows are deleted at the end, so it can be re-run.
-- =============================================================================
\pset pager off
\set ON_ERROR_STOP off

-- the next upcoming Lagos session with at least two free active seats
SELECT es.session_id AS sess, es.fee, e.code AS exam,
       to_char(es.start_time AT TIME ZONE 'Africa/Lagos', 'YYYY-MM-DD HH24:MI') AS starts
  FROM exam_session es JOIN centre c USING (centre_id) JOIN exam e USING (exam_id)
 WHERE c.code = 'LOS-01' AND es.start_time > now() + interval '1 day'
   AND es.start_time < now() + interval '40 days'
 ORDER BY es.start_time LIMIT 1 \gset
SELECT min(s.seat_id) AS seat_a, max(s.seat_id) AS seat_b
  FROM (SELECT s.seat_id FROM seat s JOIN exam_session es ON es.centre_id = s.centre_id
         WHERE es.session_id = :sess AND s.status = 'active'
           AND NOT EXISTS (SELECT 1 FROM seat_allocation sa WHERE sa.session_id = :sess AND sa.seat_id = s.seat_id)
         ORDER BY s.seat_id LIMIT 2) s \gset
-- two candidates who are free at that time
SELECT min(candidate_id) AS cand_1, max(candidate_id) AS cand_2
  FROM (SELECT c.candidate_id FROM candidate c
         WHERE NOT EXISTS (SELECT 1 FROM seat_allocation sa WHERE sa.candidate_id = c.candidate_id
                             AND sa.session_range && (SELECT session_range FROM exam_session WHERE session_id = :sess))
         ORDER BY c.candidate_id LIMIT 2) x \gset

\echo 'Session' :sess '(' :exam 'at TestPoint Lagos,' :starts ', fee ₦' :fee ')'
\echo 'Candidates' :cand_1 'and' :cand_2 '; free seats' :seat_a 'and' :seat_b
\echo ''
\echo 'BEFORE — rows in the three tables:'
SELECT (SELECT count(*) FROM registration) AS registrations,
       (SELECT count(*) FROM seat_allocation) AS allocations,
       (SELECT count(*) FROM payment) AS payments;

\echo ''
\echo '=== DEMO A — candidate' :cand_1 'takes seat' :seat_a ', valid payment ⇒ COMMIT ==='
BEGIN;
SELECT allocate_seat(:sess, :cand_1, :seat_a, :fee) AS allocation_id;
COMMIT;
SELECT (SELECT count(*) FROM registration) AS registrations,
       (SELECT count(*) FROM seat_allocation) AS allocations,
       (SELECT count(*) FROM payment) AS payments;
\echo '↑ one more row in EACH table'

\echo ''
\echo '=== DEMO B — candidate' :cand_2 'takes seat' :seat_b ', payment ₦0 ⇒ ERROR ⇒ ROLLBACK ==='
\echo '    (the registration and seat_allocation rows are inserted first, then the payment fails)'
BEGIN;
SELECT allocate_seat(:sess, :cand_2, :seat_b, 0) AS allocation_id;
ROLLBACK;
SELECT (SELECT count(*) FROM registration) AS registrations,
       (SELECT count(*) FROM seat_allocation) AS allocations,
       (SELECT count(*) FROM payment) AS payments;
\echo '↑ counts UNCHANGED since DEMO A — nothing half-written'
SELECT count(*) AS rows_holding_seat_b FROM seat_allocation WHERE session_id = :sess AND seat_id = :seat_b;
\echo '↑ 0: seat' :seat_b 'is still free'

\echo ''
\echo '=== DEMO C — candidate' :cand_2 'tries seat' :seat_b 'again with a valid payment ⇒ COMMIT ==='
BEGIN;
SELECT allocate_seat(:sess, :cand_2, :seat_b, :fee) AS allocation_id;
COMMIT;
SELECT sa.allocation_id, sa.candidate_id, sa.seat_id, p.amount, p.status AS payment
  FROM seat_allocation sa JOIN payment p USING (registration_id)
 WHERE sa.session_id = :sess AND sa.candidate_id IN (:cand_1, :cand_2) ORDER BY 1;

-- clean up the demo rows so the script can be re-run
DELETE FROM payment WHERE registration_id IN (SELECT registration_id FROM seat_allocation
                                               WHERE session_id = :sess AND candidate_id IN (:cand_1, :cand_2));
CREATE TEMP TABLE demo_regs AS SELECT registration_id FROM seat_allocation
                                WHERE session_id = :sess AND candidate_id IN (:cand_1, :cand_2);
DELETE FROM seat_allocation WHERE session_id = :sess AND candidate_id IN (:cand_1, :cand_2);
DELETE FROM registration WHERE registration_id IN (SELECT registration_id FROM demo_regs);
\echo ''
\echo 'Conclusion: the ₦0 payment rolled back the registration and the seat'
\echo 'allocation as well (atomicity), so the seat could be sold again.'
