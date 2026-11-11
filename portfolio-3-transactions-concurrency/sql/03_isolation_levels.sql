-- =============================================================================
-- Portfolio 3 — sql/03_isolation_levels.sql
-- READ COMMITTED vs REPEATABLE READ vs SERIALIZABLE — reference list.
-- These need TWO sessions at once, so do NOT run this file with -f.
--   * Automatic: python3 run_race_demos.py | tee race_demos_output.log  (Parts 4-5)
--   * By hand:   guides/race_condition_two_terminal.md, Parts 4 and 5
--                (first sql/race_setup.sql, then \i sql/race_vars.sql in BOTH psql sessions)
-- =============================================================================
-- SERIALIZABLE (Part 4)
-- A: BEGIN ISOLATION LEVEL SERIALIZABLE;  SELECT count(*) FROM seat_allocation_bug WHERE session_id = :sess AND seat_id = :seat;
-- B: BEGIN ISOLATION LEVEL SERIALIZABLE;  (same SELECT)
-- A: INSERT INTO seat_allocation_bug (session_id, seat_id, candidate_id) VALUES (:sess, :seat, :ca);
-- B: INSERT INTO seat_allocation_bug (session_id, seat_id, candidate_id) VALUES (:sess, :seat, :cb);
-- A: COMMIT;   B: COMMIT;  -- ERROR 40001 could not serialize access
-- READ COMMITTED (Part 5a): A's second count sees B's committed allocate_seat()
-- REPEATABLE READ (Part 5b): A's second count does NOT, until A commits
\echo 'Reference only — see guides/race_condition_two_terminal.md Parts 4-5,'
\echo 'or run: python3 run_race_demos.py | tee race_demos_output.log'
