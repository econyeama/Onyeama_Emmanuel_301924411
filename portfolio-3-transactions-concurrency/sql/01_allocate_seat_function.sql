-- =============================================================================
-- Portfolio 3 — sql/01_allocate_seat_function.sql
-- TestPoint CBT — the allocate_seat() transactional function.
--
-- allocate_seat(p_session_id, p_candidate_id, p_seat_id, p_amount)
--   * validates the session, the seat (active, belongs to the session's centre)
--   * checks the seat is not already allocated in this session
--   * checks the candidate is not already booked in this session
--   * inserts a registration (status='allocated')
--   * inserts a seat_allocation (the capacity trigger + EXCLUDE constraint
--     also fire here as a safety net)
--   * records the payment — if amount <= 0 the function RAISEs, which
--     rolls back the WHOLE function call (no allocation, no registration).
--
-- Because a PL/pgSQL function executes inside the caller's transaction, the
-- raise-on-failed-payment pattern gives us atomic allocate+pay: either both
-- happen or neither does. This is the COMMIT/ROLLBACK demo in 02.
-- =============================================================================

DROP FUNCTION IF EXISTS allocate_seat(BIGINT, BIGINT, BIGINT, NUMERIC) CASCADE;

CREATE OR REPLACE FUNCTION allocate_seat(
    p_session_id    BIGINT,
    p_candidate_id  BIGINT,
    p_seat_id       BIGINT,
    p_amount        NUMERIC
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_allocation_id   BIGINT;
    v_registration_id BIGINT;
    v_centre_id       BIGINT;
    v_exam_id         BIGINT;
    v_seat_status     TEXT;
    v_existing_alloc  BIGINT;
    v_session_range   tstzrange;
    v_fee             NUMERIC;
BEGIN
    ------------------------------------------------------------------
    -- 1. Load the session + its centre/exam/range/fee.
    ------------------------------------------------------------------
    SELECT es.centre_id, es.exam_id, es.session_range, es.fee
      INTO v_centre_id, v_exam_id, v_session_range, v_fee
      FROM exam_session es
     WHERE es.session_id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'allocate_seat: session % not found', p_session_id;
    END IF;

    ------------------------------------------------------------------
    -- 2. Validate the seat: exists, active, belongs to the session's centre.
    ------------------------------------------------------------------
    -- FOR UPDATE locks this seat's row until COMMIT/ROLLBACK: a second
    -- allocate_seat() for the same seat WAITS here, and when it continues it
    -- sees the first booking in step 3 and gets a clear message (Fix 2 in
    -- guides/race_condition_two_terminal.md).
    SELECT s.status
      INTO v_seat_status
      FROM seat s
     WHERE s.seat_id = p_seat_id
       AND s.centre_id = v_centre_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'allocate_seat: seat % does not exist at centre of session %',
            p_seat_id, p_session_id;
    END IF;

    IF v_seat_status <> 'active' THEN
        RAISE EXCEPTION
            'allocate_seat: seat % is not active (status: %)',
            p_seat_id, v_seat_status;
    END IF;

    ------------------------------------------------------------------
    -- 3. Check the seat is not already allocated in this session.
    ------------------------------------------------------------------
    SELECT sa.allocation_id
      INTO v_existing_alloc
      FROM seat_allocation sa
     WHERE sa.seat_id = p_seat_id
       AND sa.session_id = p_session_id;

    IF FOUND THEN
        RAISE EXCEPTION
            'allocate_seat: seat % is already allocated in session %',
            p_seat_id, p_session_id;
    END IF;

    ------------------------------------------------------------------
    -- 4. Check the candidate is not already in this session.
    ------------------------------------------------------------------
    SELECT sa.allocation_id
      INTO v_existing_alloc
      FROM seat_allocation sa
     WHERE sa.candidate_id = p_candidate_id
       AND sa.session_id = p_session_id;

    IF FOUND THEN
        RAISE EXCEPTION
            'allocate_seat: candidate % is already booked in session %',
            p_candidate_id, p_session_id;
    END IF;

    ------------------------------------------------------------------
    -- 5. Insert the registration row.
    ------------------------------------------------------------------
    INSERT INTO registration (candidate_id, exam_id, status)
    VALUES (p_candidate_id, v_exam_id, 'allocated')
    RETURNING registration_id INTO v_registration_id;

    ------------------------------------------------------------------
    -- 6. Insert the seat_allocation. The capacity trigger and the EXCLUDE
    --    constraint are the final safety net; if they fire we RAISE and
    --    the whole function call is rolled back (registration included).
    ------------------------------------------------------------------
    INSERT INTO seat_allocation
        (session_id, seat_id, candidate_id, registration_id, session_range)
    VALUES (p_session_id, p_seat_id, p_candidate_id, v_registration_id,
            v_session_range)
    RETURNING allocation_id INTO v_allocation_id;

    ------------------------------------------------------------------
    -- 7. Record the payment. amount <= 0 ⇒ RAISE ⇒ rollback.
    --    The fee advertised for the session is the expected amount; we
    --    accept the caller's amount as long as it is positive (some
    --    scenarios — surcharge, discount — vary the amount).
    ------------------------------------------------------------------
    IF p_amount <= 0 THEN
        RAISE EXCEPTION
            'allocate_seat: payment amount must be > 0 (got %)', p_amount;
    END IF;

    INSERT INTO payment (registration_id, amount, status, reference)
    VALUES (v_registration_id, p_amount, 'success',
            'ALLOC-' || v_allocation_id);

    RETURN v_allocation_id;
END;
$$;

-- Quick self-test: book the first free active seat in the next upcoming
-- Lagos session for a candidate who is free at that time, then undo it.
\echo ''
\echo '=== allocate_seat() installed. Self-test (rolled back afterwards) ==='
SELECT es.session_id AS st_sess, es.fee AS st_fee
  FROM exam_session es JOIN centre c ON c.centre_id = es.centre_id
 WHERE c.code = 'LOS-01' AND es.start_time > now() + interval '1 day'
 ORDER BY es.start_time LIMIT 1 \gset
SELECT s.seat_id AS st_seat FROM seat s JOIN exam_session es ON es.centre_id = s.centre_id
 WHERE es.session_id = :st_sess AND s.status = 'active'
   AND NOT EXISTS (SELECT 1 FROM seat_allocation sa WHERE sa.session_id = :st_sess AND sa.seat_id = s.seat_id)
 ORDER BY s.seat_id LIMIT 1 \gset
SELECT c.candidate_id AS st_cand FROM candidate c
 WHERE NOT EXISTS (SELECT 1 FROM seat_allocation sa
                    WHERE sa.candidate_id = c.candidate_id
                      AND sa.session_range && (SELECT session_range FROM exam_session WHERE session_id = :st_sess))
 ORDER BY c.candidate_id LIMIT 1 \gset
BEGIN;
SELECT allocate_seat(:st_sess, :st_cand, :st_seat, :st_fee) AS new_allocation_id;
ROLLBACK;
