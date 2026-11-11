-- =============================================================================
-- Portfolio 1 — tests/constraint_tests.sql
-- TestPoint CBT — every bad row below MUST be rejected by the database.
--
-- Each test builds its OWN data (a test session 60 days ahead at the Lagos
-- centre, a second overlapping session, two test candidates, one valid
-- booking + payment + result), and the WHOLE script runs inside
-- BEGIN … ROLLBACK, so the bulk data is left exactly as it was.
-- The script stops with an error (so run_p1.sh stops) if any test FAILS.
--
-- Usage:
--   sudo runuser -u postgres -- psql -d testpoint -f tests/constraint_tests.sql
-- =============================================================================
\set ON_ERROR_STOP on
\pset pager off

BEGIN;

CREATE TEMP TABLE p1_results (n serial, label text, result text, message text);

CREATE OR REPLACE FUNCTION pg_temp._t(label text, sql text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE sql;
        INSERT INTO p1_results(label, result, message) VALUES (label, 'FAIL', 'bad row was accepted!');
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO p1_results(label, result, message) VALUES (label, 'PASS', SQLERRM);
    END;
END$$;

-- ---------------------------------------------------------------- fixtures --
SELECT (SELECT centre_id FROM centre WHERE code = 'LOS-01')              AS los,
       (SELECT centre_id FROM centre WHERE code = 'ABJ-01')              AS abj,
       (SELECT seat_capacity FROM centre WHERE code = 'ENU-01')          AS enu_cap,
       (SELECT centre_id FROM centre WHERE code = 'ENU-01')              AS enu,
       (SELECT exam_id FROM exam WHERE code = 'PMP')                     AS pmp,
       (SELECT exam_id FROM exam WHERE code = 'AZ-900')                  AS az,
       date_trunc('day', now()) + interval '60 days 9 hours'             AS t0
\gset

INSERT INTO candidate (first_name, last_name, email, phone, gender, state_of_origin) VALUES
    ('Test', 'One', 'p1test.one@example.com', '+2348000000001', 'F', 'Lagos'),
    ('Test', 'Two', 'p1test.two@example.com', '+2348000000002', 'M', 'Enugu');
SELECT (SELECT candidate_id FROM candidate WHERE email = 'p1test.one@example.com') AS c1,
       (SELECT candidate_id FROM candidate WHERE email = 'p1test.two@example.com') AS c2
\gset

-- session S1: PMP at Lagos, 09:00-13:00, 60 days ahead
INSERT INTO exam_session (centre_id, exam_id, session_date, start_time, end_time, session_range, fee)
VALUES (:los, :pmp, (:'t0'::timestamptz)::date, :'t0', :'t0'::timestamptz + interval '4 hours',
        tstzrange(:'t0', :'t0'::timestamptz + interval '4 hours', '[)'), 75000)
RETURNING session_id AS s1 \gset
-- session S2: AZ-900 at Abuja, 10:00-11:30 the same day (overlaps S1)
INSERT INTO exam_session (centre_id, exam_id, session_date, start_time, end_time, session_range, fee)
VALUES (:abj, :az, (:'t0'::timestamptz)::date, :'t0'::timestamptz + interval '1 hour', :'t0'::timestamptz + interval '150 minutes',
        tstzrange(:'t0'::timestamptz + interval '1 hour', :'t0'::timestamptz + interval '150 minutes', '[)'), 25000)
RETURNING session_id AS s2 \gset

SELECT (SELECT seat_id FROM seat WHERE centre_id = :los AND status = 'active' ORDER BY seat_id LIMIT 1)          AS seat_a,
       (SELECT seat_id FROM seat WHERE centre_id = :los AND status = 'active' ORDER BY seat_id LIMIT 1 OFFSET 1) AS seat_b,
       (SELECT seat_id FROM seat WHERE centre_id = :los AND status = 'maintenance' LIMIT 1)                     AS seat_maint,
       (SELECT seat_id FROM seat WHERE centre_id = :abj AND status = 'active' ORDER BY seat_id LIMIT 1)          AS seat_abj
\gset

-- registrations: c1 PMP, c2 PMP, c1 AZ-900
INSERT INTO registration (candidate_id, exam_id, status) VALUES (:c1, :pmp, 'allocated') RETURNING registration_id AS r1 \gset
INSERT INTO registration (candidate_id, exam_id, status) VALUES (:c2, :pmp, 'allocated') RETURNING registration_id AS r2 \gset
INSERT INTO registration (candidate_id, exam_id, status) VALUES (:c1, :az,  'allocated') RETURNING registration_id AS r3 \gset

-- one VALID booking: c1 on seat A in S1, paid, so the "duplicates" really are duplicates
INSERT INTO seat_allocation (session_id, seat_id, candidate_id, registration_id)
VALUES (:s1, :seat_a, :c1, :r1) RETURNING allocation_id AS a1 \gset
INSERT INTO payment (registration_id, amount, status, reference) VALUES (:r1, 75000, 'success', 'P1TEST-1');

\echo ''
\echo 'Test fixtures: session' :s1 '(PMP, Lagos) and overlapping session' :s2 '(AZ-900, Abuja); valid booking' :a1
\echo ''
\o /dev/null

SELECT pg_temp._t('T1. UNIQUE candidate per session: c1 gets a 2nd seat in S1',
  format('INSERT INTO seat_allocation (session_id, seat_id, candidate_id, registration_id) VALUES (%s,%s,%s,%s)', :s1, :seat_b, :c1, :r1));
SELECT pg_temp._t('T2. UNIQUE seat per session: seat A given to c2 in S1',
  format('INSERT INTO seat_allocation (session_id, seat_id, candidate_id, registration_id) VALUES (%s,%s,%s,%s)', :s1, :seat_a, :c2, :r2));
SELECT pg_temp._t('T3. EXCLUDE overlap: c1 booked into overlapping S2',
  format('INSERT INTO seat_allocation (session_id, seat_id, candidate_id, registration_id) VALUES (%s,%s,%s,%s)', :s2, :seat_abj, :c1, :r3));
SELECT pg_temp._t('T4. trigger: seat from another centre (Abuja seat in Lagos session)',
  format('INSERT INTO seat_allocation (session_id, seat_id, candidate_id, registration_id) VALUES (%s,%s,%s,%s)', :s1, :seat_abj, :c2, :r2));
SELECT pg_temp._t('T5. trigger: seat under maintenance',
  format('INSERT INTO seat_allocation (session_id, seat_id, candidate_id, registration_id) VALUES (%s,%s,%s,%s)', :s1, :seat_maint, :c2, :r2));
SELECT pg_temp._t('T6. trigger: registration of another candidate',
  format('INSERT INTO seat_allocation (session_id, seat_id, candidate_id, registration_id) VALUES (%s,%s,%s,%s)', :s1, :seat_b, :c2, :r1));
SELECT pg_temp._t('T7. CHECK payment > 0: amount = 0',
  format('INSERT INTO payment (registration_id, amount, reference) VALUES (%s, 0, ''P1TEST-0'')', :r2));
SELECT pg_temp._t('T8. CHECK payment <= 100000: amount = 250000',
  format('INSERT INTO payment (registration_id, amount, reference) VALUES (%s, 250000, ''P1TEST-BIG'')', :r2));
SELECT pg_temp._t('T9. UNIQUE payment reference: same reference twice',
  format('INSERT INTO payment (registration_id, amount, reference) VALUES (%s, 75000, ''P1TEST-1'')', :r2));
SELECT pg_temp._t('T10. CHECK score 0-100: score = 150',
  format('INSERT INTO result (allocation_id, candidate_id, exam_id, score) VALUES (%s,%s,%s,150)', :a1, :c1, :pmp));
SELECT pg_temp._t('T11. session that ends before it starts',
  format('INSERT INTO exam_session (centre_id, exam_id, session_date, start_time, end_time, session_range, fee) '
         'VALUES (%s,%s,%L::date,%L::timestamptz + interval ''5 hours'',%L,tstzrange(%L::timestamptz, %L::timestamptz + interval ''1 hour''),75000)', :los, :pmp, :'t0', :'t0', :'t0', :'t0', :'t0'));
SELECT pg_temp._t('T12. CHECK duration 30-480 min: 600-minute exam',
  'INSERT INTO exam (code, title, body, category, duration_minutes, default_fee) VALUES (''BAD'',''Bad'',''X'',''recruitment_test'',600,1000)');
SELECT pg_temp._t('T13. CHECK category: unknown exam category',
  'INSERT INTO exam (code, title, body, category, duration_minutes, default_fee) VALUES (''BAD2'',''Bad'',''X'',''school_exam'',60,1000)');
SELECT pg_temp._t('T14. UNIQUE candidate email',
  'INSERT INTO candidate (first_name, last_name, email, phone) VALUES (''Dup'',''Email'',''p1test.one@example.com'',''+2348000000009'')');

-- T15: centre capacity trigger. Fill a 60-seat Enugu session to capacity, then add one more.
INSERT INTO exam_session (centre_id, exam_id, session_date, start_time, end_time, session_range, fee)
VALUES (:enu, :az, (:'t0'::timestamptz + interval '5 days')::date, :'t0'::timestamptz + interval '5 days',
        :'t0'::timestamptz + interval '5 days 90 minutes',
        tstzrange(:'t0'::timestamptz + interval '5 days', :'t0'::timestamptz + interval '5 days 90 minutes', '[)'), 25000)
RETURNING session_id AS s3 \gset
-- (the capacity trigger counts allocations; Enugu has 60 seats, 57 active, so
--  for this test only we mark every seat active)
UPDATE seat SET status = 'active' WHERE centre_id = :enu;
INSERT INTO candidate (first_name, last_name, email, phone)
SELECT 'Cap', 'Test' || g, 'p1cap' || g || '@example.com', '+23481' || lpad(g::text, 8, '0')
FROM generate_series(1, :enu_cap + 1) g;
INSERT INTO registration (candidate_id, exam_id, status)
SELECT candidate_id, :az, 'allocated' FROM candidate WHERE email LIKE 'p1cap%';
INSERT INTO seat_allocation (session_id, seat_id, candidate_id, registration_id)
SELECT :s3, s.seat_id, r.candidate_id, r.registration_id
FROM (SELECT seat_id, row_number() OVER (ORDER BY seat_id) rn FROM seat WHERE centre_id = :enu) s
JOIN (SELECT registration_id, candidate_id, row_number() OVER (ORDER BY registration_id) rn
      FROM registration WHERE exam_id = :az AND candidate_id IN (SELECT candidate_id FROM candidate WHERE email LIKE 'p1cap%')) r
  ON r.rn = s.rn;
SELECT (SELECT registration_id FROM registration WHERE candidate_id = (SELECT candidate_id FROM candidate WHERE email = 'p1cap' || (:enu_cap + 1) || '@example.com')) AS r_extra,
       (SELECT candidate_id FROM candidate WHERE email = 'p1cap' || (:enu_cap + 1) || '@example.com') AS c_extra,
       (SELECT count(*) FROM seat_allocation WHERE session_id = :s3) AS s3_full
\gset
-- a 61st seat number does not exist, so add a temporary extra seat first
INSERT INTO seat (centre_id, seat_number, computer_name) VALUES (:enu, 'X999', 'enu01-pc-x999') RETURNING seat_id AS seat_extra \gset
SELECT pg_temp._t('T15. trigger: session already full (' || :s3_full || ' of ' || :enu_cap || ' seats)',
  format('INSERT INTO seat_allocation (session_id, seat_id, candidate_id, registration_id) VALUES (%s,%s,%s,%s)', :s3, :seat_extra, :c_extra, :r_extra));

\o
\echo '====================================================================='
\echo '            CONSTRAINT TESTS (every bad row must be rejected)'
\echo '====================================================================='
SELECT label AS test, result, message AS database_said FROM p1_results ORDER BY n;

SELECT count(*) FILTER (WHERE result = 'PASS') AS passed, count(*) AS total,
       count(*) FILTER (WHERE result = 'FAIL') > 0 AS any_failed
FROM p1_results \gset

ROLLBACK;   -- remove every test row; the bulk data is untouched

\echo ''
\echo 'Result:' :passed 'of' :total 'bad inserts were rejected. (All test rows rolled back.)'
\if :any_failed
  \echo 'SOME CONSTRAINT TESTS FAILED (see FAIL rows above)'
  SELECT 1/0 AS constraint_tests_failed;
\endif
