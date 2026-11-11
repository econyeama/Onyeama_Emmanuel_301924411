-- =============================================================================
-- Portfolio 3 — sql/race_setup.sql
-- Fixtures for the two-terminal demos (Parts 1-6). Safe to re-run.
--   * one demo session 45 days ahead: PMP at TestPoint Lagos, 09:00-13:00
--   * three demo candidates: Chiamaka Obi (Terminal A, Lagos front desk),
--     Yusuf Danladi (Terminal B, online portal), Grace Etim (Part 5)
--   * three free seats (A, B, C) at the Lagos centre for that session
--   * seat_allocation_bug — a copy with NO unique rule (Parts 1, 2, 4)
--   * race_demo — the ids, loaded into psql with  \i sql/race_vars.sql
-- Run:  sudo runuser -u postgres -- psql -d testpoint -f sql/race_setup.sql
-- =============================================================================
\set ON_ERROR_STOP on
CREATE TABLE IF NOT EXISTS race_demo (key text PRIMARY KEY, val bigint NOT NULL);

-- remove the previous demo run
DELETE FROM payment WHERE registration_id IN (
    SELECT registration_id FROM registration WHERE candidate_id IN
      (SELECT candidate_id FROM candidate WHERE email LIKE 'race.demo.%'));
DELETE FROM seat_allocation WHERE candidate_id IN (SELECT candidate_id FROM candidate WHERE email LIKE 'race.demo.%');
DELETE FROM registration    WHERE candidate_id IN (SELECT candidate_id FROM candidate WHERE email LIKE 'race.demo.%');
DELETE FROM seat_allocation WHERE session_id IN (SELECT val FROM race_demo WHERE key = 'sess');
DELETE FROM exam_session    WHERE session_id IN (SELECT val FROM race_demo WHERE key = 'sess');
TRUNCATE race_demo;

INSERT INTO candidate (first_name, last_name, email, phone, gender, state_of_origin) VALUES
    ('Chiamaka', 'Obi',     'race.demo.chiamaka@example.com', '+2348035550101', 'F', 'Anambra'),
    ('Yusuf',    'Danladi', 'race.demo.yusuf@example.com',    '+2348065550202', 'M', 'Kaduna'),
    ('Grace',    'Etim',    'race.demo.grace@example.com',    '+2348095550303', 'F', 'Cross River')
ON CONFLICT (email) DO NOTHING;

WITH d AS (SELECT (date_trunc('day', now() AT TIME ZONE 'Africa/Lagos') + interval '45 days 9 hours')
                  AT TIME ZONE 'Africa/Lagos' AS t0)
INSERT INTO exam_session (centre_id, exam_id, session_date, start_time, end_time, session_range, fee)
SELECT c.centre_id, e.exam_id, (d.t0 AT TIME ZONE 'Africa/Lagos')::date, d.t0, d.t0 + interval '4 hours',
       tstzrange(d.t0, d.t0 + interval '4 hours', '[)'), e.default_fee
FROM d, centre c, exam e WHERE c.code = 'LOS-01' AND e.code = 'PMP';

INSERT INTO race_demo (key, val)
SELECT 'sess', max(session_id) FROM exam_session es JOIN centre c USING (centre_id)
 WHERE c.code = 'LOS-01' AND es.start_time > now() + interval '40 days'
UNION ALL SELECT 'ca', candidate_id FROM candidate WHERE email = 'race.demo.chiamaka@example.com'
UNION ALL SELECT 'cb', candidate_id FROM candidate WHERE email = 'race.demo.yusuf@example.com'
UNION ALL SELECT 'cc', candidate_id FROM candidate WHERE email = 'race.demo.grace@example.com'
UNION ALL SELECT 'fee', 75000;
INSERT INTO race_demo (key, val)
SELECT k, seat_id FROM (
  SELECT seat_id, (ARRAY['seat','seat2','seat3'])[row_number() OVER (ORDER BY seat_id)] AS k
  FROM seat s JOIN centre c USING (centre_id)
  WHERE c.code = 'LOS-01' AND s.status = 'active' ORDER BY seat_id LIMIT 3) x;

DROP TABLE IF EXISTS seat_allocation_bug;
CREATE TABLE seat_allocation_bug (
    bug_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id   BIGINT NOT NULL,
    seat_id      BIGINT NOT NULL,
    candidate_id BIGINT NOT NULL,
    allocated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    -- NO unique (seat_id, session_id), NO trigger: anything goes
);

\echo ''
\echo 'Demo fixtures ready:'
SELECT d.key, d.val,
       COALESCE(c.first_name || ' ' || c.last_name,
                'seat ' || s.seat_number || ' at ' || sc.code,
                ce.code || ' ' || e.code || ' session on ' || to_char(es.start_time AT TIME ZONE 'Africa/Lagos', 'YYYY-MM-DD HH24:MI'),
                'fee (₦)') AS meaning
FROM race_demo d
LEFT JOIN candidate c     ON d.key IN ('ca','cb','cc') AND c.candidate_id = d.val
LEFT JOIN seat s          ON d.key LIKE 'seat%' AND s.seat_id = d.val
LEFT JOIN centre sc       ON sc.centre_id = s.centre_id
LEFT JOIN exam_session es ON d.key = 'sess' AND es.session_id = d.val
LEFT JOIN centre ce       ON ce.centre_id = es.centre_id
LEFT JOIN exam e          ON e.exam_id = es.exam_id
ORDER BY d.key;
