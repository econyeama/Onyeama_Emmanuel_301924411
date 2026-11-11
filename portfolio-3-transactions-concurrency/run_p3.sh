#!/usr/bin/env bash
# =============================================================================
# Portfolio 3 — run_p3.sh
# TestPoint CBT — Transactions and Concurrency.
#
# This script runs the SINGLE-TERMINAL parts of Portfolio 3:
#   * installs the allocate_seat() function
#   * runs the COMMIT / ROLLBACK atomicity demo
#
# The TWO-TERMINAL parts (race condition, isolation levels, deadlock) are
# interactive — they need two psql sessions side by side and are documented
# in:
#   guides/race_condition_two_terminal.md
#   sql/03_isolation_levels.sql   (instructions inside the file)
#   sql/04_deadlock_demo.sql      (instructions inside the file)
#
# Codespaces rules: sudo runuser -u postgres -- psql, Unix socket.
# =============================================================================
set -euo pipefail

PORTFOLIO_DIR="$(cd "$(dirname "$0")" && pwd)"
DB="${TP_DB:-testpoint}"

echo "==================================================================="
echo " Portfolio 3 — Transactions and Concurrency (TestPoint CBT)"
echo "==================================================================="

echo "[p3] installing allocate_seat() function"
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d "${DB}" \
    -f "${PORTFOLIO_DIR}/sql/01_allocate_seat_function.sql"

echo ""
echo "[p3] running COMMIT/ROLLBACK atomicity demo (failed payment ⇒ rollback)"
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=0 -d "${DB}" \
    -f "${PORTFOLIO_DIR}/sql/02_commit_rollback_demo.sql"

echo ""
echo "[p3] race-demo fixtures + all six two-session demos (two real database sessions at once)"
sudo runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 -d "${DB}" -f "${PORTFOLIO_DIR}/sql/race_setup.sql"
(cd "${PORTFOLIO_DIR}" && python3 run_race_demos.py | tee race_demos_output.log)

echo ""
echo "[p3] DONE. Evidence: race_demos_output.log (Parts 1-6)."
echo "[p3] Optional, by hand in two terminals: guides/race_condition_two_terminal.md"
echo ""
echo "[p3] What to screenshot:"
echo "[p3]   1. allocate_seat() self-test output (new_allocation_id)."
echo "[p3]   2. DEMO A COMMIT row counts (before/after)."
echo "[p3]   3. DEMO B ROLLBACK row counts (unchanged) + the caught exception."
echo "[p3]   4. The bug: two rows with the same (seat, session) in seat_allocation_bug."
echo "[p3]   5. Fix 1: the duplicate-key error in Terminal B."
echo "[p3]   6. Fix 2: Terminal B blocked on SELECT FOR UPDATE, then the clear message."
echo "[p3]   7. SERIALIZABLE SQLSTATE 40001 from the isolation demo."
echo "[p3]   8. Deadlock SQLSTATE 40P01 from the deadlock demo."
echo ""
echo "[p3] Git commit (from repo root):"
echo "    git add portfolio-3-transactions-concurrency/ && \\"
echo "    git commit -m 'feat(p3): allocate_seat txn, COMMIT/ROLLBACK, race condition guide, isolation, deadlock' && \\"
echo "    git tag p3-txn"
echo "==================================================================="
