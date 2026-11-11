-- =============================================================================
-- Portfolio 2 — indexes/create_indexes.sql
-- TestPoint CBT — indexes added BETWEEN the "before" and "after" EXPLAIN runs.
--
-- These indexes target the join and filter columns that the 8 queries hit:
--
--   * seat_allocation(session_id)        — Q1, Q3, Q8 (and the EXCLUDE index
--                                          already covers candidate_id + range,
--                                          but NOT session_id alone).
--   * seat_allocation(candidate_id)      — Q2 (count DISTINCT candidate).
--   * exam_session(exam_id)              — Q2, Q7.
--   * exam_session(centre_id)            — Q3, Q6.
--   * exam_session(session_date)         — Q2 (date_trunc month grouping).
--   * result(exam_id)                    — Q4.
--   * payment(registration_id)           — Q6, Q7.
--   * payment(status, amount)            — Q6, Q7 (covering for status filter).
--   * registration(registration_id, candidate_id) — Q6, Q7.
--
-- Connection: Unix socket.
--   sudo runuser -u postgres -- psql -d testpoint \
--       -f portfolio-2-query-optimisation/indexes/create_indexes.sql
-- =============================================================================

\echo 'Creating optimisation indexes …'

-- Single-column B-tree indexes on the hot filter/join columns.
CREATE INDEX IF NOT EXISTS idx_sa_session_id
    ON seat_allocation (session_id);

CREATE INDEX IF NOT EXISTS idx_sa_candidate_id
    ON seat_allocation (candidate_id);

CREATE INDEX IF NOT EXISTS idx_es_exam_id
    ON exam_session (exam_id);

CREATE INDEX IF NOT EXISTS idx_es_centre_id
    ON exam_session (centre_id);

CREATE INDEX IF NOT EXISTS idx_es_session_date
    ON exam_session (session_date);

CREATE INDEX IF NOT EXISTS idx_result_exam_id
    ON result (exam_id);

CREATE INDEX IF NOT EXISTS idx_payment_registration_id
    ON payment (registration_id);

-- Q9: one candidate's results (help-desk lookup)
CREATE INDEX IF NOT EXISTS idx_result_candidate_id
    ON result (candidate_id);

ANALYZE;

-- Partial / covering index: most queries only care about successful payments,
-- and they always read amount — a partial covering index is the smallest, fastest
-- structure for Q6 and Q7.
CREATE INDEX IF NOT EXISTS idx_payment_success_amount
    ON payment (amount)
    INCLUDE (registration_id)
    WHERE status = 'success';

\echo ''
\echo 'Index list after creation (screenshot this for evidence):'
SELECT schemaname, tablename, indexname, indexdef
  FROM pg_indexes
 WHERE schemaname = 'public'
   AND tablename IN ('seat_allocation','exam_session','result','payment')
 ORDER BY tablename, indexname;
