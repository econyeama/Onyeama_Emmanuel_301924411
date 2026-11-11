#!/usr/bin/env bash
# =============================================================================
# Portfolio 5 — run_p5.sh
# TestPoint CBT — Distributed and Cloud Database Exercise.
#
# Steps:
#   1. Partition seat_allocation by month (sql/01_partitioning.sql).
#   2. Build a primary + streaming read replica (sql/02_replica_setup.sh).
#   3. Run the replica tests (sql/03_replica_tests.sql): replica rejects
#      writes, new rows on the primary appear on the replica.
#
# The cloud architecture and CAP/sync-vs-async write-ups are in docs/.
#
# Codespaces rules honoured: sudo runuser -u postgres --, Unix sockets,
# pg_ctl at /usr/lib/postgresql/16/bin/pg_ctl, no postgres_fdw.
# =============================================================================
set -euo pipefail

PORTFOLIO_DIR="$(cd "$(dirname "$0")" && pwd)"
DB="${TP_DB:-testpoint}"

echo "==================================================================="
echo " Portfolio 5 — Distributed and Cloud Database Exercise"
echo "==================================================================="

echo ""
echo "[p5] step 1 — partitioning seat_allocation by month"
sudo runuser -u postgres -- psql -X -v ON_ERROR_STOP=1 -d "${DB}" \
    -f "${PORTFOLIO_DIR}/sql/01_partitioning.sql" 2>&1 | tee "${PORTFOLIO_DIR}/partition_output.log"

echo ""
echo "[p5] step 2 — set up primary + streaming replica (interactive-ish;"
echo "    restarts the primary cluster to apply wal_level/pg_hba changes)"
bash "${PORTFOLIO_DIR}/sql/02_replica_setup.sh" 2>&1 | tee "${PORTFOLIO_DIR}/replication_output.log"

echo ""
echo "[p5] step 3 — replica tests: replica rejects writes + new rows arrive"
sudo runuser -u postgres -- psql -X -v ON_ERROR_STOP=0 -d "${DB}" \
    -f "${PORTFOLIO_DIR}/sql/03_replica_tests.sql" 2>&1 | tee -a "${PORTFOLIO_DIR}/replication_output.log"

echo ""
echo "[p5] DONE."
echo "[p5] What to screenshot:"
echo "[p5]   1. The monthly partitions + rows per month (partition_output.log)."
echo "[p5]   2. The partition-pruning EXPLAIN output (1 partition scanned"
echo "[p5]      vs every partition scanned without the date filter)."
echo "[p5]   3. The replica setup verification:"
echo "[p5]        SELECT pg_is_in_recovery();  on port 5432 (false) and"
echo "[p5]                                     on port 5433 (true)."
echo "[p5]        SELECT * FROM pg_stat_replication;  on the primary."
echo "[p5]   4. T1 — the replica INSERT error (read-only transaction)."
echo "[p5]   5. T2 — the marker row appearing on the replica after ~1 s."
echo "[p5]   6. T3 — pg_stat_replication lag in bytes + replay_lag interval."
echo "[p5]   7. Render docs/cloud_architecture.md and docs/cap_tradeoffs.md"
echo "[p5]      to PDF (or include the markdown) as the discussion evidence."
echo ""
echo "[p5] Git commit (from repo root):"
echo "    git add portfolio-5-distributed-cloud/ && \\"
echo "    git commit -m 'feat(p5): monthly partitioning, primary+streaming replica, NDPA-2023 cloud arch, CAP' && \\"
echo "    git tag p5-distributed"
echo "==================================================================="
