-- =============================================================================
-- Portfolio 1 — schema/05_seed.sql
-- TestPoint CBT — small, readable seed data (NOT the 50k bulk set).
--
-- Inserts the skeleton of the business so that ad-hoc psql work and the
-- constraint tests have realistic rows:
--   * 5 centres  (Lagos, Abuja, Ibadan, Enugu, Kano) with realistic capacities
--   * 9 exams    (mix of professional certs + recruitment tests + language)
--   * seats      (one row per computer per centre, via generate_series)
--   * 8 candidates
--   * 5 sessions in the next few days (relative to CURRENT_DATE)
--   * 6 registrations, 6 allocations, 6 payments, 5 results
--
-- All dates are relative to CURRENT_DATE so the seed never "expires".
-- Run AFTER 02_tables.sql, 03_constraints.sql, 04_triggers.sql.
-- =============================================================================

-- 5 centres (capacities reflect typical Nigerian CBT labs)
INSERT INTO centre (code, name, city, address, seat_capacity) VALUES
    ('LOS-01', 'TestPoint CBT Lagos Victoria Island', 'Lagos',
     '12 Akin Adesola Street, Victoria Island, Lagos', 120),
    ('ABJ-01', 'TestPoint CBT Abuja Central Area', 'Abuja',
     'Plot 789 Constitution Avenue, Central Business District, Abuja', 100),
    ('IBD-01', 'TestPoint CBT Ibadan Bodija', 'Ibadan',
     '5 Bodija Road, Ibadan, Oyo State', 80),
    ('ENU-01', 'TestPoint CBT Enugu Independence', 'Enugu',
     '22 Independence Avenue, Enugu', 60),
    ('KAN-01', 'TestPoint CBT Kano Farm Centre', 'Kano',
     'Farm Centre Road, Nasarawa, Kano', 90);

-- 9 exams
INSERT INTO exam (code, title, body, category, duration_minutes, default_fee) VALUES
    ('PMP',      'Project Management Professional', 'PMI',   'professional_certification', 240, 75000),
    ('CCNA',     'Cisco Certified Network Associate', 'Cisco','professional_certification', 120, 45000),
    ('AZ-900',   'Microsoft Azure Fundamentals', 'Microsoft', 'professional_certification', 90, 25000),
    ('ACCA-F6',  'ACCA Taxation (TX-F6)', 'ACCA',  'professional_certification', 180, 60000),
    ('ICAN-PE1', 'ICAN Professional Examination I', 'ICAN',  'professional_certification', 180, 55000),
    ('TOEFL',    'TOEFL iBT', 'ETS',   'language_test',            180, 55000),
    ('IELTS',    'IELTS Academic', 'British Council', 'language_test', 165, 60000),
    ('NNPC-REC', 'NNPC Graduate Recruitment Test', 'NNPC', 'recruitment_test', 120, 15000),
    ('CBN-REC',  'CBN Recruitment Aptitude Test', 'CBN',  'recruitment_test', 90,  15000);

-- Generate seats per centre (A001..Annn) using generate_series.
INSERT INTO seat (centre_id, seat_number, computer_name, status)
SELECT c.centre_id,
       'A' || lpad(g.s::text, 3, '0'),
       lower(replace(c.code, '-', '')) || '-pc-' || lpad(g.s::text, 3, '0'),
       CASE WHEN g.s % 17 = 0 THEN 'maintenance' ELSE 'active' END
  FROM centre c
  CROSS JOIN generate_series(1, c.seat_capacity) AS g(s);

-- 8 candidates (realistic Nigerian names across Yoruba/Igbo/Hausa)
INSERT INTO candidate (first_name, last_name, email, phone, gender, state_of_origin) VALUES
    ('Chidi',     'Okonkwo',  'chidi.okonkwo@example.com',    '+2348031112221', 'M', 'Anambra'),
    ('Aisha',     'Bello',    'aisha.bello@example.com',      '+2348061112222', 'F', 'Kano'),
    ('Tunde',     'Adeyemi',  'tunde.adeyemi@example.com',    '+2348051112223', 'M', 'Lagos'),
    ('Ngozi',     'Eze',      'ngozi.eze@example.com',        '+2348021112224', 'F', 'Enugu'),
    ('Ibrahim',   'Mohammed', 'ibrahim.mohammed@example.com', '+2348071112225', 'M', 'Kaduna'),
    ('Bola',      'Oluwole',  'bola.oluwole@example.com',     '+2348051112226', 'F', 'Oyo'),
    ('Emeka',     'Nwosu',    'emeka.nwosu@example.com',      '+2348031112227', 'M', 'Imo'),
    ('Fatima',    'Yusuf',    'fatima.yusuf@example.com',     '+2348061112228', 'F', 'Kano');

-- 5 sessions over the next 7 days (relative to today, never expires).
-- Two are at Lagos (PMP morning + AZ-900 afternoon), one each at Abuja (CCNA),
-- Ibadan (TOEFL), Kano (NNPC-REC). session_range is computed explicitly.
INSERT INTO exam_session
    (centre_id, exam_id, session_date, start_time, end_time, session_range, fee, status)
SELECT c.centre_id, e.exam_id,
       (CURRENT_DATE + n)::date AS session_date,
       (CURRENT_DATE + n)::timestamp + start_offset AS start_time,
       (CURRENT_DATE + n)::timestamp + start_offset
           + (e.duration_minutes || ' minutes')::INTERVAL AS end_time,
       tstzrange(
           (CURRENT_DATE + n)::timestamp + start_offset,
           (CURRENT_DATE + n)::timestamp + start_offset
               + (e.duration_minutes || ' minutes')::INTERVAL, '[)') AS session_range,
       e.default_fee AS fee,
       'completed' AS status   -- seed sessions are in the PAST (they have results)
  FROM (VALUES
        ('LOS-01','PMP',     -2, INTERVAL '9 hours'),
        ('LOS-01','AZ-900',  -2, INTERVAL '13 hours'),
        ('ABJ-01','CCNA',    -3, INTERVAL '9 hours'),
        ('IBD-01','TOEFL',   -4, INTERVAL '9 hours'),
        ('KAN-01','NNPC-REC',-5, INTERVAL '9 hours')
       ) AS v(code, exam, n, start_offset)
  JOIN centre c ON c.code = v.code
  JOIN exam  e ON e.code = v.exam;

-- Helper: register + allocate a candidate onto a specific seat in a specific
-- session, and optionally record a payment + result. We use a small function
-- so the seed stays readable.
CREATE OR REPLACE FUNCTION _seed_book(
    p_session_id    BIGINT,
    p_candidate_id  BIGINT,
    p_seat_number   TEXT,
    p_pay           BOOLEAN DEFAULT TRUE,
    p_score         NUMERIC DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_reg     BIGINT;
    v_alloc   BIGINT;
    v_seat    BIGINT;
    v_exam_id BIGINT;
    v_fee     NUMERIC;
BEGIN
    SELECT exam_id, fee INTO v_exam_id, v_fee
      FROM exam_session WHERE session_id = p_session_id;

    SELECT seat_id INTO v_seat
      FROM seat s
      JOIN exam_session es ON es.centre_id = s.centre_id
     WHERE es.session_id = p_session_id AND s.seat_number = p_seat_number;

    INSERT INTO registration (candidate_id, exam_id, status)
    VALUES (p_candidate_id, v_exam_id, 'allocated')
    RETURNING registration_id INTO v_reg;

    INSERT INTO seat_allocation
        (session_id, seat_id, candidate_id, registration_id, session_range, attended)
    SELECT p_session_id, v_seat, p_candidate_id, v_reg, es.session_range, true
      FROM exam_session es WHERE es.session_id = p_session_id
    RETURNING allocation_id INTO v_alloc;

    IF p_pay THEN
        INSERT INTO payment (registration_id, amount, status, reference)
        VALUES (v_reg, v_fee, 'success', 'SEED-' || v_reg::text);
    END IF;

    IF p_score IS NOT NULL THEN
        INSERT INTO result (allocation_id, candidate_id, exam_id, score)
        VALUES (v_alloc, p_candidate_id, v_exam_id, p_score);
    END IF;
END;
$$;

-- Book 6 candidates across the 5 sessions, deliberately leaving most seats
-- empty so Portfolio 2's "free seats" query has rows to return.
-- (session_id is assigned by BIGSERIAL in insertion order: 1..5.)
SELECT _seed_book(1, 1, 'A001', true, 82.50);   -- PMP Lagos, Chidi, passed
SELECT _seed_book(1, 2, 'A002', true, 67.00);   -- PMP Lagos, Aisha, passed
SELECT _seed_book(2, 3, 'A001', true, 45.00);   -- AZ-900 Lagos, Tunde, failed (<50)
SELECT _seed_book(2, 4, 'A002', true, 71.00);   -- AZ-900 Lagos, Ngozi, passed
SELECT _seed_book(3, 5, 'A001', true, 90.00);   -- CCNA Abuja, Ibrahim, passed
SELECT _seed_book(4, 6, 'A001', true, NULL);    -- TOEFL Ibadan, Bola, attended but not graded
SELECT _seed_book(5, 7, 'A001', false, NULL);   -- NNPC-REC Kano, Emeka, payment NOT made

-- A no-show: candidate 8 booked into Lagos PMP (session 1) on seat A003,
-- checked_in=false, attended=false, but paid — for the no-show-rate query.
SELECT _seed_book(1, 8, 'A003', true, NULL);
UPDATE seat_allocation SET attended = false, checked_in = false
 WHERE session_id = 1 AND candidate_id = 8;

-- Mark one registration 'no_show' for reporting realism.
UPDATE registration
   SET status = 'no_show'
 WHERE candidate_id = 8 AND exam_id = (SELECT exam_id FROM exam WHERE code='PMP');

-- Drop the helper so it does not leak into the schema.
DROP FUNCTION _seed_book(BIGINT, BIGINT, TEXT, BOOLEAN, NUMERIC);
