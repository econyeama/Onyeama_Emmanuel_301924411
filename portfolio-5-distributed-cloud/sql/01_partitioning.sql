-- =============================================================================
-- Portfolio 5 — sql/01_partitioning.sql
-- TestPoint CBT — range-partition seat_allocation by month.
--
-- The bulk generator (Portfolio 1) loads ~55,000 rows into seat_allocation
-- spanning ~2 years. Reporting queries with a date filter (e.g. "revenue for
-- March 2026") currently Seq-Scan the whole table. Partitioning by month
-- lets PostgreSQL prune to a single monthly partition.
--
-- This script:
--   1. Creates a NEW partitioned parent table seat_allocation_part that
--      mirrors the seat_allocation schema but adds PARTITION BY RANGE
--      (allocated_at).
--   2. Creates 24 monthly partitions covering the 2-year bulk-data window,
--      computed relative to CURRENT_DATE (never expires).
--   3. Migrates rows from seat_allocation into seat_allocation_part.
--   4. Builds the partition pruning demo: a query filtered by month hits
--      ONLY the relevant partition.
--
-- Connection: Unix socket.
--   sudo runuser -u postgres -- psql -d testpoint \
--       -f portfolio-5-distributed-cloud/sql/01_partitioning.sql
-- =============================================================================

\set ON_ERROR_STOP on
\echo ''
\echo '=== Portfolio 5 — partitioning seat_allocation by month ==='
\echo ''

-- -----------------------------------------------------------------------------
-- 1. Parent partitioned table.
--    We use a separate table (seat_allocation_part) so the original
--    seat_allocation is untouched and the demo is reproducible.
--    All constraints from the original are inherited by partitions.
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS seat_allocation_part CASCADE;

CREATE TABLE seat_allocation_part (
    allocation_id   BIGSERIAL,
    session_id      BIGINT      NOT NULL,
    seat_id         BIGINT      NOT NULL,
    candidate_id    BIGINT      NOT NULL,
    registration_id BIGINT      NOT NULL,
    session_range   tstzrange   NOT NULL,
    allocated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    checked_in      BOOLEAN     NOT NULL DEFAULT false,
    attended        BOOLEAN     NOT NULL DEFAULT false,
    PRIMARY KEY (allocation_id, allocated_at)   -- partition key must be in PK
) PARTITION BY RANGE (allocated_at);

-- -----------------------------------------------------------------------------
-- 2. Create one partition per month covering ALL the data (from the month of
--    the oldest allocation to 3 months after the newest), plus a DEFAULT
--    partition as a safety net. (A fixed "12 months back" window failed:
--    the bulk data goes back two years, so INSERT found no partition.)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    d      DATE := date_trunc('month', (SELECT min(allocated_at) FROM seat_allocation))::date;
    d_end  DATE := (date_trunc('month', (SELECT max(allocated_at) FROM seat_allocation)) + INTERVAL '3 months')::date;
    p_next DATE;
BEGIN
    WHILE d < d_end LOOP
        p_next := (d + INTERVAL '1 month')::date;
        EXECUTE format('CREATE TABLE %I PARTITION OF seat_allocation_part FOR VALUES FROM (%L) TO (%L);',
                       'seat_allocation_part_' || to_char(d, 'YYYY_MM'), d, p_next);
        d := p_next;
    END LOOP;
    CREATE TABLE seat_allocation_part_default PARTITION OF seat_allocation_part DEFAULT;
END $$;

SELECT count(*) AS partitions FROM pg_inherits WHERE inhparent = 'seat_allocation_part'::regclass;
\echo 'Partitions created. List:'
SELECT c.relname AS partition
  FROM pg_inherits i
  JOIN pg_class c ON c.oid = i.inhrelid
 WHERE i.inhparent = 'seat_allocation_part'::regclass
 ORDER BY c.relname;

-- -----------------------------------------------------------------------------
-- 3. Migrate rows from the original seat_allocation into the partitioned table.
--    allocated_at drives which partition each row lands in.
-- -----------------------------------------------------------------------------
\echo ''
\echo 'Migrating rows from seat_allocation -> seat_allocation_part …'
INSERT INTO seat_allocation_part
    (allocation_id, session_id, seat_id, candidate_id, registration_id,
     session_range, allocated_at, checked_in, attended)
SELECT allocation_id, session_id, seat_id, candidate_id, registration_id,
       session_range, allocated_at, checked_in, attended
  FROM seat_allocation
 ORDER BY allocated_at;

ANALYZE seat_allocation_part;
\echo 'Rows per partition (exact; screenshot this for evidence):'
SELECT replace(tableoid::regclass::text, 'seat_allocation_part_', '') AS month, count(*) AS rows
  FROM seat_allocation_part GROUP BY tableoid ORDER BY 1;
SELECT (SELECT count(*) FROM seat_allocation) AS rows_in_original,
       (SELECT count(*) FROM seat_allocation_part) AS rows_in_partitioned;

-- -----------------------------------------------------------------------------
-- 4. Partition pruning demo.
--    A query filtered to one month should scan ONLY that month's partition.
--    Show the plan BEFORE (Seq Scan on the whole parent would be impossible
--    because the parent is partitioned; instead, without a date filter ALL
--    partitions are scanned) and AFTER (with a date filter only one is).
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== Partition pruning demo ==='
\echo ''
SELECT (date_trunc('month', now()) - interval '12 months')::date AS m0,
       (date_trunc('month', now()) - interval '11 months')::date AS m1 \gset
\echo '--- WITHOUT date filter: ALL partitions scanned ---'
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON) SELECT count(*) FROM seat_allocation_part;

\echo ''
\echo '--- WITH a one-month filter (' :m0 '): only ONE partition scanned ---'
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON)
SELECT count(*) FROM seat_allocation_part
 WHERE allocated_at >= :'m0' AND allocated_at < :'m1';

\echo ''
\echo '--- same one-month question on the UNPARTITIONED table ---'
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON)
SELECT count(*) FROM seat_allocation
 WHERE allocated_at >= :'m0' AND allocated_at < :'m1';
