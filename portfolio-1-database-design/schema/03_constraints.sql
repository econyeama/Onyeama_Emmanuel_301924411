-- =============================================================================
-- Portfolio 1 — schema/03_constraints.sql
-- TestPoint CBT — advanced constraints.
--
-- These are layered on top of 02_tables.sql so the normalisation notes can
-- reference each named constraint explicitly.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- C1. One seat per candidate per session.
--     A candidate cannot appear twice in the same session (even on different
--     seats) — they only get one computer.
-- -----------------------------------------------------------------------------
ALTER TABLE seat_allocation
    ADD CONSTRAINT uq_allocation_candidate_per_session
    UNIQUE (candidate_id, session_id);

-- -----------------------------------------------------------------------------
-- C2. No seat given to two candidates in the same session.
--     A physical computer can host only one candidate per session.
-- -----------------------------------------------------------------------------
ALTER TABLE seat_allocation
    ADD CONSTRAINT uq_allocation_seat_per_session
    UNIQUE (seat_id, session_id);

-- -----------------------------------------------------------------------------
-- C3. A candidate cannot be booked into two overlapping sessions.
--     Implemented as a GiST EXCLUDE constraint (requires btree_gist) over the
--     copied session_range tstzrange. Overlap is the && operator.
--
--     Without this constraint a candidate booked into a 09:00–11:00 session
--     in Lagos and a 10:30–12:30 session in Abuja on the same day would be
--     physically impossible but the DB would allow it.
-- -----------------------------------------------------------------------------
ALTER TABLE seat_allocation
    ADD CONSTRAINT excl_candidate_no_overlap
    EXCLUDE USING gist (
        candidate_id   WITH =,
        session_range  WITH &&
    );

-- -----------------------------------------------------------------------------
-- C4. Payment amount must be strictly positive.
--     (Named so the test file can DROP / reference it explicitly.)
-- -----------------------------------------------------------------------------
ALTER TABLE payment
    ADD CONSTRAINT chk_payment_amount_positive
    CHECK (amount > 0);

-- -----------------------------------------------------------------------------
-- C5. Exam score must be between 0 and 100 inclusive.
-- -----------------------------------------------------------------------------
ALTER TABLE result
    ADD CONSTRAINT chk_result_score_range
    CHECK (score >= 0 AND score <= 100);

-- -----------------------------------------------------------------------------
-- C6. A payment's amount cannot exceed the session fee by more than a small
--     tolerance (some exams allow a ₦500 admin surcharge). Kept generous so
--     the bulk generator does not trip it accidentally.
-- -----------------------------------------------------------------------------
ALTER TABLE payment
    ADD CONSTRAINT chk_payment_amount_reasonable
    CHECK (amount <= 100000);

-- ---------------------------------------------------------------------------
-- Index the foreign key seat_allocation.session_id. The capacity trigger
-- counts the allocations of a session on EVERY insert; without this index
-- that count is a full-table scan per row, and loading 50k+ allocations takes
-- many minutes instead of seconds.
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_allocation_session ON seat_allocation (session_id);
