# Portfolio 5 — Distributed and Cloud Database Exercise

**Portfolio:** 5 · **Marks:** 6 · **Study sessions covered:** Study Session 2
(*Distributed Database System*: replication, fragmentation, CAP theorem,
consistency models) + Study Session 3 (*Cloud Database Systems*) + Study
Session 6 (*Data Security and Data Privacy* — NDPA 2023 compliance).

## What this portfolio demonstrates

| Concept | File |
|---|---|
| Partition `seat_allocation` by month into 24 monthly partitions + partition-pruning demo | `sql/01_partitioning.sql` |
| Primary + streaming read replica on the same Codespace (primary port 5432, replica port 5433) | `sql/02_replica_setup.sh` |
| Replica tests: replica rejects writes, new rows on primary arrive on replica, lag metrics | `sql/03_replica_tests.sql` |
| Cloud architecture keeping data in Nigeria under NDPA 2023 | `docs/cloud_architecture.md` |
| CAP theorem, sync vs async replication trade-offs, exam-day traffic peaks | `docs/cap_tradeoffs.md` |

## How to run (Codespaces)

```bash
bash portfolio-5-distributed-cloud/run_p5.sh
```

The script:

1. Runs `01_partitioning.sql` — creates a partitioned parent
   `seat_allocation_part` with 24 monthly partitions (12 months back + 12
   forward from today), migrates the bulk data into it, and runs the
   partition-pruning `EXPLAIN` demo.
2. Runs `02_replica_setup.sh` — configures the primary for replication
   (`wal_level=replica`, `max_wal_senders`), prepends trust lines to the
   **top** of `pg_hba.conf`, restarts the primary, creates a `repl` role
   and a physical replication slot, runs `pg_basebackup -R -S replica1`
   into a fresh replica data directory, writes the replica's **own**
   `postgresql.conf` (port 5433, `hot_standby=on`, Unix socket dir), and
   starts the replica with `pg_ctl`.
3. Runs `03_replica_tests.sql` — inserts a marker row on the primary,
   waits 1 s, reads it on the replica; attempts an `INSERT` on the replica
   and captures the "read-only transaction" error; queries
   `pg_stat_replication` for lag.

## Codespaces rules honoured (recap)

| Rule | Where it is honoured |
|---|---|
| `sudo runuser -u postgres --` (never `sudo -u postgres`) | Every psql / pg_ctl / pg_basebackup call in `02_replica_setup.sh` and `run_p5.sh` |
| PostgreSQL config in `/etc/postgresql/16/main/` | `PG_CONF`, `PG_HBA` variables in `02_replica_setup.sh` |
| `pg_ctl` at `/usr/lib/postgresql/16/bin/pg_ctl` | `PG_BIN` variable; replica started with the full path |
| Replica needs its own `postgresql.conf` | `02_replica_setup.sh` step 7 appends overrides to `${REPLICA_DATA}/postgresql.conf` |
| `pg_hba.conf` trust lines at the top | Steps 2 and 7 prepend the trust block (with a marker) so it shadows the default `local all postgres peer` line below |
| TCP logins need a password → use the Unix socket | `unix_socket_directories='/var/run/postgresql'` on the replica; every psql call uses the default socket |
| No `postgres_fdw` | Replication is native physical streaming replication; no foreign server / user mapping anywhere |
| Dates relative to today | Partition boundaries use `CURRENT_DATE`; the 2-year window auto-slides |

## What to screenshot (for the LMS evidence)

| Screenshot | Where it comes from |
|---|---|
| 24 monthly partitions listed | `01_partitioning.sql` |
| Partition pruning: `EXPLAIN` with a date filter scans 1 partition | `01_partitioning.sql` |
| `SELECT pg_is_in_recovery()` on primary (false) and replica (true) | `02_replica_setup.sh` verification |
| `SELECT * FROM pg_stat_replication` on the primary | `02_replica_setup.sh` verification |
| T1 — replica `INSERT` rejected with "read-only transaction" | `03_replica_tests.sql` |
| T2 — marker row appearing on the replica after 1 s | `03_replica_tests.sql` |
| T3 — `pg_stat_replication` lag bytes + replay lag interval | `03_replica_tests.sql` |
| Cloud architecture diagram (rendered) | `docs/cloud_architecture.md` |

## Git commit (from repo root)

```bash
git add portfolio-5-distributed-cloud/ && \
git commit -m "feat(p5): monthly partitioning, primary+streaming replica, NDPA-2023 cloud arch, CAP" && \
git tag p5-distributed
```

## Plain-English explanation

This portfolio answers **"can you distribute a database across machines and
reason about the trade-offs?"** Three concrete pieces of evidence are
produced:

1. **Partitioning** — `seat_allocation_part` is split into 24 monthly
   partitions. A reporting query filtered by one month prunes to that one
   partition instead of Seq-Scanning two years of data. This is the
   single-node version of the sharding strategy that would scale TestPoint
   horizontally once a single primary can no longer keep up with exam-day
   writes.
2. **Streaming replication** — a real physical replica is built with
   `pg_basebackup`, started with `pg_ctl` on port 5433, and verified to (a)
   reject writes (read-only transaction) and (b) receive new rows committed
   on the primary within ~1 second. The replica is the on-ramp to the
   read-scaling and DR strategy described in the cloud architecture doc.
3. **Cloud architecture + CAP** — the docs describe a production deployment
   that keeps all candidate personal data inside Nigeria (Lagos primary +
   sync standby, Abuja async DR) to comply with the NDPA 2023, chooses CP
   for the seat-allocation write path and AP for the read-mostly reporting
   and question-bank paths, and absorbs exam-day bursts with PgBouncer +
   Redis + Kubernetes HPA + read replicas.

This maps to **Study Session 2** (CAP, ACID/BASE, consistency models),
**Study Session 3** (cloud database systems), and **Study Session 6**
(data privacy under the NDPA 2023).
