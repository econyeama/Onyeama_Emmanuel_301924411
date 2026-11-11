-- =============================================================================
-- Portfolio 1 — schema/04_triggers.sql
-- TestPoint CBT — triggers.
--
-- T1. trg_check_session_capacity
--     BEFORE INSERT OR UPDATE on seat_allocation: the number of allocations
--     for the target session must not exceed the seat_capacity of the centre
--     the session belongs to. This is the CBT-specific capacity rule: a
--     session can use up to the centre's whole computer lab, but no more.
--
-- T2. trg_sync_session_range
--     BEFORE INSERT on seat_allocation: copy session_range from the parent
--     exam_session so the EXCLUDE constraint (C3) has the right value without
--     the application having to know it.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- T1: capacity trigger.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_check_session_capacity() CASCADE;
DROP TRIGGER IF EXISTS trg_check_session_capacity ON seat_allocation;

CREATE OR REPLACE FUNCTION fn_check_session_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_centre_capacity INTEGER;
    v_current_count   INTEGER;
BEGIN
    SELECT c.seat_capacity
      INTO v_centre_capacity
      FROM exam_session s
      JOIN centre c ON c.centre_id = s.centre_id
     WHERE s.session_id = NEW.session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Session % does not exist', NEW.session_id;
    END IF;

    SELECT count(*)
      INTO v_current_count
      FROM seat_allocation
     WHERE session_id = NEW.session_id
       AND allocation_id <> NEW.allocation_id;

    IF v_current_count >= v_centre_capacity THEN
        RAISE EXCEPTION
            'Session % is full: centre capacity is %, already allocated %',
            NEW.session_id, v_centre_capacity, v_current_count;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_check_session_capacity
    BEFORE INSERT OR UPDATE OF session_id ON seat_allocation
    FOR EACH ROW
    EXECUTE FUNCTION fn_check_session_capacity();

-- -----------------------------------------------------------------------------
-- T2: keep session_range in sync with the parent exam_session.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_sync_session_range() CASCADE;
DROP TRIGGER IF EXISTS trg_sync_session_range ON seat_allocation;

CREATE OR REPLACE FUNCTION fn_sync_session_range()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT session_range
      INTO NEW.session_range
      FROM exam_session
     WHERE session_id = NEW.session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Session % does not exist', NEW.session_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_session_range
    BEFORE INSERT ON seat_allocation
    FOR EACH ROW
    WHEN (NEW.session_range IS NULL)
    EXECUTE FUNCTION fn_sync_session_range();

-- ---------------------------------------------------------------------------
-- 3. fn_check_allocation_consistency — rules that need OTHER tables:
--      * the seat must be in the same centre as the session, and active
--        (not under maintenance / decommissioned)
--      * the registration must belong to the same candidate and be for the
--        same exam as the session
--      * the copied session_range must equal the session's real time range
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_check_allocation_consistency() CASCADE;

CREATE OR REPLACE FUNCTION fn_check_allocation_consistency()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_sess  exam_session%ROWTYPE;
    v_seat  seat%ROWTYPE;
    v_reg   registration%ROWTYPE;
BEGIN
    SELECT * INTO v_sess FROM exam_session WHERE session_id = NEW.session_id;
    SELECT * INTO v_seat FROM seat         WHERE seat_id    = NEW.seat_id;
    SELECT * INTO v_reg  FROM registration WHERE registration_id = NEW.registration_id;

    IF v_seat.centre_id IS DISTINCT FROM v_sess.centre_id THEN
        RAISE EXCEPTION 'Seat % is not in the centre of session %', NEW.seat_id, NEW.session_id
            USING ERRCODE = 'check_violation';
    END IF;
    IF v_seat.status <> 'active' THEN
        RAISE EXCEPTION 'Seat % is %, not active', v_seat.seat_number, v_seat.status
            USING ERRCODE = 'check_violation';
    END IF;
    IF v_reg.candidate_id IS DISTINCT FROM NEW.candidate_id
       OR v_reg.exam_id IS DISTINCT FROM v_sess.exam_id THEN
        RAISE EXCEPTION 'Registration % is not this candidate''s registration for this exam', NEW.registration_id
            USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.session_range IS DISTINCT FROM v_sess.session_range THEN
        RAISE EXCEPTION 'session_range does not match session %', NEW.session_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

-- Triggers fire in name order.
-- "trg_z_" makes this one run LAST, after
-- trg_sync_session_range has filled in session_range.
CREATE TRIGGER trg_z_check_allocation_consistency
    BEFORE INSERT OR UPDATE ON seat_allocation
    FOR EACH ROW
    EXECUTE FUNCTION fn_check_allocation_consistency();
