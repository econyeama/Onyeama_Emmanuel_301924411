#!/usr/bin/env bash
# =============================================================================
# Portfolio 1 — run_p1.sh
# TestPoint CBT — Database Design and Modelling.
#
# Builds the schema, runs the small seed, runs the constraint tests, then
# runs the bulk generator to produce 50k+ seat allocations.
#
# Run from the repo root in a GitHub Codespace (after setup.sh):
#   bash portfolio-1-database-design/run_p1.sh
#
# Codespaces rules honoured:
#   * sudo runuser -u postgres -- psql   (NOT sudo -u postgres)
#   * host=/var/run/postgresql           (Unix socket, peer auth, no password)
#   * all dates relative to CURRENT_DATE / date.today()
# =============================================================================
set -euo pipefail

PORTFOLIO_DIR="$(cd "$(dirname "$0")" && pwd)"
DB="${TP_DB:-testpoint}"

echo "==================================================================="
echo " Portfolio 1 — Database Design and Modelling (TestPoint CBT)"
echo "==================================================================="

# 1. (Re)create a fresh database so the run is idempotent.
echo "[p1] recreating database '${DB}'"
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS ${DB};"
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${DB} OWNER testpoint;"
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -c "ALTER DATABASE ${DB} SET timezone TO 'Africa/Lagos';"

# 2. Apply schema files in order: extensions → tables → constraints → triggers.
echo "[p1] applying schema (extensions, tables, constraints, triggers)"
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d "${DB}" \
    -f "${PORTFOLIO_DIR}/schema/01_extensions.sql"
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d "${DB}" \
    -f "${PORTFOLIO_DIR}/schema/02_tables.sql"
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d "${DB}" \
    -f "${PORTFOLIO_DIR}/schema/03_constraints.sql"
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d "${DB}" \
    -f "${PORTFOLIO_DIR}/schema/04_triggers.sql"

# 3. Seed small, readable data.
echo "[p1] seeding small dataset (5 centres, 9 exams, 8 candidates, 5 sessions)"
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d "${DB}" \
    -f "${PORTFOLIO_DIR}/schema/05_seed.sql"

# 4. Show the row counts after seeding (screenshot-worthy).
echo "[p1] row counts after seed:"
sudo runuser -u postgres -- psql -d "${DB}" -c "
SELECT 'centre'          AS tbl, count(*) FROM centre
UNION ALL SELECT 'exam',         count(*) FROM exam
UNION ALL SELECT 'seat',         count(*) FROM seat
UNION ALL SELECT 'candidate',    count(*) FROM candidate
UNION ALL SELECT 'exam_session', count(*) FROM exam_session
UNION ALL SELECT 'registration', count(*) FROM registration
UNION ALL SELECT 'seat_allocation', count(*) FROM seat_allocation
UNION ALL SELECT 'payment',      count(*) FROM payment
UNION ALL SELECT 'result',       count(*) FROM result
ORDER BY 1;"

# 5. Run the bulk generator → 50k+ seat allocations (2 years + next 90 days).
#    It connects as YOUR Linux user over the Unix socket (peer auth); setup.sh
#    created that database role. (PGUSER=postgres fails: peer auth only lets
#    the Linux user "postgres" log in as "postgres".)
echo "[p1] running bulk data generator (50k+ seat allocations over 2 years)"
PGHOST=/var/run/postgresql python3 "${PORTFOLIO_DIR}/bulk_data/generate_bulk.py"

# 6. Constraint tests AFTER the bulk load: they build their own rows and roll
#    back, so the bulk data is untouched. Stops the script if any test fails.
echo "[p1] running constraint tests (every bad insert must be rejected)"
sudo runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 -d "${DB}" \
    -f "${PORTFOLIO_DIR}/tests/constraint_tests.sql"

# 7. Final counts for evidence.
echo "[p1] final row counts (screenshot this):"
sudo runuser -u postgres -- psql -d "${DB}" -c "
SELECT 'centre'          AS tbl, count(*) FROM centre
UNION ALL SELECT 'exam',         count(*) FROM exam
UNION ALL SELECT 'seat',         count(*) FROM seat
UNION ALL SELECT 'candidate',    count(*) FROM candidate
UNION ALL SELECT 'exam_session', count(*) FROM exam_session
UNION ALL SELECT 'registration', count(*) FROM registration
UNION ALL SELECT 'seat_allocation', count(*) FROM seat_allocation
UNION ALL SELECT 'payment',      count(*) FROM payment
UNION ALL SELECT 'result',       count(*) FROM result
ORDER BY 1;"

echo ""
echo "[p1] DONE."
echo "[p1] What to screenshot:"
echo "[p1]   1. The row-counts table above (after seed + after bulk)."
echo "[p1]   2. The constraint-tests table (15 PASS rows + 'Result: 15 of 15')."
echo "[p1]   3. The BULK DATA SUMMARY block printed by generate_bulk.py."
echo "[p1]   4. The ER diagram — drawn on the P1 README page on GitHub."
echo ""
echo "[p1] Git commit command (run from repo root):"
echo "    git add portfolio-1-database-design/ && \\"
echo "    git commit -m 'feat(p1): schema, 3NF notes, ER diagram, 50k+ bulk data, constraint tests' && \\"
echo "    git tag p1-design"
echo "==================================================================="
