-- =============================================================================
-- Portfolio 5 — sql/03_replica_tests.sql
-- TestPoint CBT — streaming-replica behaviour tests.
--
-- Run AFTER 02_replica_setup.sh has created the primary (port 5432) and the
-- streaming replica (port 5433).
--
-- The script does TWO things:
--   T1. The replica REJECTS writes (it is in hot-standby / recovery mode).
--       We attempt an INSERT on port 5433 and capture the error.
--   T2. New rows inserted on the PRIMARY appear on the REPLICA within
--       milliseconds. We insert a marker row, wait 1 s, then read it back
--       from the replica.
--
-- Codespaces rules: connect through the Unix socket (no TCP, no password).
--   Primary : sudo runuser -u postgres -- psql -p 5432 -d testpoint
--   Replica : sudo runuser -u postgres -- psql -p 5433 -d testpoint
--
-- This ONE script switches between the servers itself with
--   \connect -reuse-previous=off testpoint - /var/run/postgresql 5432|5433
-- (The old version used \! sudo … inside psql; psql runs as the postgres
--  user, who cannot use sudo, so every replica check failed.)
-- =============================================================================

\set ON_ERROR_STOP off
\echo ''
\echo '=== Portfolio 5 — replica tests ==='
\echo ''

-- -----------------------------------------------------------------------------
-- T1. The replica rejects writes.
-- -----------------------------------------------------------------------------
\connect -reuse-previous=off testpoint - /var/run/postgresql 5433
SELECT 'REPLICA' AS server, current_setting('port') AS port, pg_is_in_recovery() AS in_recovery;
\echo '--- T1. Attempt an INSERT on the REPLICA (port 5433). Must be rejected ---'
\echo '    (expected: ERROR: cannot execute INSERT in a read-only transaction)'
\echo ''
INSERT INTO exam (code, title, body, category, duration_minutes, default_fee) VALUES ('P5-REPLICA-WRITE-TEST', 'Replica write test (should fail)', 'TestPoint', 'professional_certification', 60, 100);

\echo ''
\echo '    Confirm the row did NOT land on the replica:'
\connect -reuse-previous=off testpoint - /var/run/postgresql 5433
SELECT count(*) AS replica_rows_with_test_code FROM exam WHERE code = 'P5-REPLICA-WRITE-TEST';

-- -----------------------------------------------------------------------------
-- T2. New rows on the PRIMARY appear on the REPLICA.
-- -----------------------------------------------------------------------------
\echo ''
\connect -reuse-previous=off testpoint - /var/run/postgresql 5432
SELECT 'PRIMARY' AS server, current_setting('port') AS port, pg_is_in_recovery() AS in_recovery;
\echo '--- T2. Insert a marker row on the PRIMARY (port 5432), then read it on the REPLICA ---'
\echo ''
INSERT INTO exam (code, title, body, category, duration_minutes, default_fee)
VALUES ('P5-REPLICA-PROOF', 'Replica proof row', 'TestPoint',
        'professional_certification', 60, 100);

\echo '    Primary: marker row inserted. Waiting 1 s for streaming replay …'
SELECT pg_sleep(1);

\echo '    Replica: read the marker row back (should now exist):'
\connect -reuse-previous=off testpoint - /var/run/postgresql 5433
SELECT code, title, default_fee FROM exam WHERE code = 'P5-REPLICA-PROOF';

-- -----------------------------------------------------------------------------
-- T3. Replication lag (in bytes and seconds).
-- -----------------------------------------------------------------------------
\echo ''
\connect -reuse-previous=off testpoint - /var/run/postgresql 5432
\echo '--- T3. Replication lag on the primary ---'
SELECT application_name,
       state,
       sync_state,
       sent_lsn   AS primary_sent,
       replay_lsn AS replica_replayed,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
  FROM pg_stat_replication;

\echo ''
\echo '--- T3b. Replica-side view: how far behind is recovery? ---'
\connect -reuse-previous=off testpoint - /var/run/postgresql 5433
SELECT now() - pg_last_xact_replay_timestamp() AS replay_lag_interval, pg_last_wal_replay_lsn() AS last_replayed_lsn;

\connect -reuse-previous=off testpoint - /var/run/postgresql 5432
-- Cleanup the marker rows so re-runs are clean.
DELETE FROM exam WHERE code IN ('P5-REPLICA-PROOF','P5-REPLICA-WRITE-TEST');
SELECT pg_sleep(1);
\echo ''
\echo '    Replica after cleanup (marker rows gone via streaming):'
\connect -reuse-previous=off testpoint - /var/run/postgresql 5433
SELECT count(*) AS replica_marker_rows_left FROM exam WHERE code LIKE 'P5-REPLICA%';

\echo ''
\echo '=== Replica tests done ==='
\echo 'Screenshot:'
\echo '  T1 — the replica INSERT error (read-only transaction).'
\echo '  T2 — the marker row appearing on the replica after ~1 s.'
\echo '  T3 — the lag in bytes / seconds from pg_stat_replication.'
