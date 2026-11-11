-- =============================================================================
-- Portfolio 1 — schema/02_tables.sql
-- TestPoint CBT — relational schema (9 tables).
--
-- All tables created here WITHOUT the advanced constraints/triggers; those
-- are added in 03_constraints.sql and 04_triggers.sql so the layered build
-- matches the normalisation notes (P1/docs/normalisation.md).
--
-- Connection: Unix socket, peer auth (host=/var/run/postgresql, user=postgres)
-- =============================================================================

-- Clean slate (idempotent re-run during development)
DROP TABLE IF EXISTS result          CASCADE;
DROP TABLE IF EXISTS payment         CASCADE;
DROP TABLE IF EXISTS seat_allocation CASCADE;
DROP TABLE IF EXISTS registration    CASCADE;
DROP TABLE IF EXISTS seat            CASCADE;
DROP TABLE IF EXISTS exam_session    CASCADE;
DROP TABLE IF EXISTS candidate       CASCADE;
DROP TABLE IF EXISTS exam            CASCADE;
DROP TABLE IF EXISTS centre          CASCADE;

-- -----------------------------------------------------------------------------
-- 1. centre  — a physical CBT facility in a Nigerian city.
--             seat_capacity is the number of working computers at the centre.
-- -----------------------------------------------------------------------------
CREATE TABLE centre (
    centre_id     BIGSERIAL    PRIMARY KEY,
    code          TEXT         NOT NULL UNIQUE,        -- e.g. 'LOS-01'
    name          TEXT         NOT NULL,
    city          TEXT         NOT NULL,                -- Lagos, Abuja, Ibadan, Enugu, Kano
    address       TEXT         NOT NULL,
    seat_capacity INTEGER      NOT NULL CHECK (seat_capacity > 0),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 2. exam  — a definition of a testable exam (e.g. PMP, CCNA, NNPC recruitment).
--            default_fee is the advertised fee in NGN; per-session fee can vary.
-- -----------------------------------------------------------------------------
CREATE TABLE exam (
    exam_id          BIGSERIAL   PRIMARY KEY,
    code             TEXT        NOT NULL UNIQUE,      -- 'PMP', 'CCNA', 'NNPC-REC'
    title            TEXT        NOT NULL,
    body             TEXT        NOT NULL,              -- exam body / sponsor
    category         TEXT        NOT NULL CHECK (category IN
                        ('professional_certification','recruitment_test','language_test')),
    duration_minutes INTEGER     NOT NULL CHECK (duration_minutes BETWEEN 30 AND 480),
    default_fee      NUMERIC(10,2) NOT NULL CHECK (default_fee >= 0),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 3. exam_session  — a concrete session of an exam at a centre on a date/time.
--    session_range is a tstzrange that spans [start_time, end_time); it is
--    used by the EXCLUDE constraint on seat_allocation (candidate cannot be
--    in two overlapping sessions) and by reporting queries.
-- -----------------------------------------------------------------------------
CREATE TABLE exam_session (
    session_id     BIGSERIAL    PRIMARY KEY,
    centre_id      BIGINT       NOT NULL REFERENCES centre(centre_id),
    exam_id        BIGINT       NOT NULL REFERENCES exam(exam_id),
    session_date   DATE         NOT NULL,               -- the calendar day
    start_time     TIMESTAMPTZ  NOT NULL,
    end_time       TIMESTAMPTZ  NOT NULL,
    session_range  tstzrange    NOT NULL,               -- = tstzrange(start_time, end_time)
    fee            NUMERIC(10,2) NOT NULL CHECK (fee >= 0),
    status         TEXT         NOT NULL DEFAULT 'scheduled'
                    CHECK (status IN ('scheduled','ongoing','completed','cancelled')),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT session_time_sane CHECK (end_time > start_time),
    CONSTRAINT session_range_matches
        CHECK (session_range = tstzrange(start_time, end_time, '[)'))
);

-- -----------------------------------------------------------------------------
-- 4. seat  — a physical computer at a centre. seat_number is unique per centre.
-- -----------------------------------------------------------------------------
CREATE TABLE seat (
    seat_id      BIGSERIAL    PRIMARY KEY,
    centre_id    BIGINT       NOT NULL REFERENCES centre(centre_id),
    seat_number  TEXT         NOT NULL,                 -- 'A01', 'A02', ...
    computer_name TEXT        NOT NULL,                 -- hostname for inventory
    status       TEXT         NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active','maintenance','decommissioned')),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (centre_id, seat_number)
);

-- -----------------------------------------------------------------------------
-- 5. candidate  — a person who registers for exams. Unique email + phone.
-- -----------------------------------------------------------------------------
CREATE TABLE candidate (
    candidate_id  BIGSERIAL    PRIMARY KEY,
    first_name    TEXT         NOT NULL,
    last_name     TEXT         NOT NULL,
    email         TEXT         NOT NULL UNIQUE,
    phone         TEXT         NOT NULL UNIQUE,
    gender        TEXT         CHECK (gender IN ('M','F')),
    state_of_origin TEXT,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 6. registration  — a candidate signing up to take a specific exam. One
--    candidate can register for an exam multiple times on different dates
--    (re-sits), so the PK is registration_id, not (candidate_id, exam_id).
-- -----------------------------------------------------------------------------
CREATE TABLE registration (
    registration_id BIGSERIAL   PRIMARY KEY,
    candidate_id    BIGINT      NOT NULL REFERENCES candidate(candidate_id),
    exam_id         BIGINT      NOT NULL REFERENCES exam(exam_id),
    registered_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    status          TEXT        NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','paid','allocated','attended','no_show','cancelled'))
);

-- -----------------------------------------------------------------------------
-- 7. seat_allocation  — the actual booking of a candidate onto a seat in a
--    session. This is the table that the bulk generator fills with 50k+ rows.
--    session_range is copied from the exam_session so that the EXCLUDE
--    constraint (candidate cannot be in two overlapping sessions) can be a
--    single-table gist constraint.
-- -----------------------------------------------------------------------------
CREATE TABLE seat_allocation (
    allocation_id  BIGSERIAL   PRIMARY KEY,
    session_id     BIGINT      NOT NULL REFERENCES exam_session(session_id),
    seat_id        BIGINT      NOT NULL REFERENCES seat(seat_id),
    candidate_id   BIGINT      NOT NULL REFERENCES candidate(candidate_id),
    registration_id BIGINT     NOT NULL REFERENCES registration(registration_id),
    session_range  tstzrange   NOT NULL,                -- copied from exam_session
    allocated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    checked_in     BOOLEAN     NOT NULL DEFAULT false,
    attended       BOOLEAN     NOT NULL DEFAULT false
);

-- -----------------------------------------------------------------------------
-- 8. payment  — one payment per registration. amount > 0 enforced in
--    03_constraints.sql as a named CHECK so the test file can reference it.
-- -----------------------------------------------------------------------------
CREATE TABLE payment (
    payment_id       BIGSERIAL    PRIMARY KEY,
    registration_id  BIGINT       NOT NULL REFERENCES registration(registration_id),
    amount           NUMERIC(10,2) NOT NULL,
    paid_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    status           TEXT         NOT NULL DEFAULT 'success'
                      CHECK (status IN ('success','failed','refunded')),
    reference        TEXT         NOT NULL UNIQUE       -- paystack/flutterwave ref
);

-- -----------------------------------------------------------------------------
-- 9. result  — the exam score for an attended allocation. score 0–100.
-- -----------------------------------------------------------------------------
CREATE TABLE result (
    result_id    BIGSERIAL   PRIMARY KEY,
    allocation_id BIGINT     NOT NULL UNIQUE REFERENCES seat_allocation(allocation_id),
    candidate_id BIGINT      NOT NULL REFERENCES candidate(candidate_id),
    exam_id      BIGINT      NOT NULL REFERENCES exam(exam_id),
    score        NUMERIC(5,2) NOT NULL,
    graded_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
