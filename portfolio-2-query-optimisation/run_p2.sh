#!/usr/bin/env bash
# =============================================================================
# Portfolio 2 — run_p2.sh
# TestPoint CBT — Query Processing and Optimisation.
#
# Runs every query with EXPLAIN ANALYZE TWICE:
#   (1) BEFORE  — only PK / UNIQUE / EXCLUDE indexes exist (left over from P1).
#   (2) AFTER   — after indexes/create_indexes.sql has been applied.
#
# Both runs print to the terminal; capture them with:
#   bash portfolio-2-query-optimisation/run_p2.sh 2>&1 | tee p2_output.txt
# then paste the relevant EXPLAIN ANALYZE blocks into
# results/before_after_table.md (replacing each [paste real output here]).
#
# Assumes Portfolio 1 has already been run (database testpoint with 50k+
# seat allocations exists).
#
# Codespaces rules: sudo runuser -u postgres -- psql, Unix socket.
# =============================================================================
set -euo pipefail

PORTFOLIO_DIR="$(cd "$(dirname "$0")" && pwd)"
DB="${TP_DB:-testpoint}"

run_query_set () {
    local label="$1"
    echo ""
    echo "###############################################################"
    echo " $label — running 9 queries with EXPLAIN ANALYZE"
    echo "###############################################################"
    for q in "${PORTFOLIO_DIR}"/queries/*.sql; do
        echo ""
        echo "----- ${label}: $(basename "$q") -----"
        sudo runuser -u postgres -- psql -X -v ON_ERROR_STOP=1 -d "${DB}" \
            -f "$q"
    done 2>&1 | tee "${PORTFOLIO_DIR}/results/explain_$(echo "$label" | tr A-Z a-z).txt"
}

echo "==================================================================="
echo " Portfolio 2 — Query Processing and Optimisation (TestPoint CBT)"
echo "==================================================================="

# 0. Sanity-check that P1 left us data.
echo "[p2] row counts in ${DB}:"
sudo runuser -u postgres -- psql -d "${DB}" -c "
SELECT 'seat_allocation' AS tbl, count(*) FROM seat_allocation
UNION ALL SELECT 'exam_session', count(*) FROM exam_session
UNION ALL SELECT 'result', count(*) FROM result
UNION ALL SELECT 'payment', count(*) FROM payment;"

# 1. Drop any optimisation indexes from a previous run so the BEFORE pass is clean.
echo "[p2] dropping any pre-existing optimisation indexes for a clean BEFORE run"
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d "${DB}" <<'SQL'
DROP INDEX IF EXISTS idx_sa_session_id;
DROP INDEX IF EXISTS idx_sa_candidate_id;
DROP INDEX IF EXISTS idx_es_exam_id;
DROP INDEX IF EXISTS idx_es_centre_id;
DROP INDEX IF EXISTS idx_es_session_date;
DROP INDEX IF EXISTS idx_result_exam_id;
DROP INDEX IF EXISTS idx_payment_registration_id;
DROP INDEX IF EXISTS idx_payment_success_amount;
DROP INDEX IF EXISTS idx_result_candidate_id;
ANALYZE;   -- fresh statistics after the P1 bulk load, so BEFORE and AFTER are fair
SQL

mkdir -p "${PORTFOLIO_DIR}/results"

# 2. BEFORE pass.
run_query_set "BEFORE"

# 3. Apply indexes.
echo ""
echo "[p2] applying optimisation indexes"
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d "${DB}" \
    -f "${PORTFOLIO_DIR}/indexes/create_indexes.sql"

# 4. AFTER pass.
run_query_set "AFTER"

echo ""
echo "==================================================================="
echo " SUMMARY — Execution Time per query (real numbers from this run)"
echo "==================================================================="
summ() { awk '/^----- /{q=$3} /Execution Time/{t[q]=$3} END{for (k in t) print k, t[k]}' "$1" | sort; }
printf "%-34s %12s %12s %9s\n" "Query" "BEFORE (ms)" "AFTER (ms)" "speed-up"
join <(summ "${PORTFOLIO_DIR}/results/explain_before.txt") <(summ "${PORTFOLIO_DIR}/results/explain_after.txt") | \
  awk '{ printf "%-34s %12.3f %12.3f %8.1fx\n", $1, $2, $3, ($3>0 ? $2/$3 : 0) }'

echo ""
echo "[p2] DONE."
echo "[p2] What to screenshot / paste:"
echo "[p2]   1. The BEFORE EXPLAIN ANALYZE block for each of the 9 queries."
echo "[p2]   2. The index list printed by create_indexes.sql."
echo "[p2]   3. The AFTER  EXPLAIN ANALYZE block for each of the 9 queries."
echo "[p2]   4. Paste each plan + the two Execution Time lines into"
echo "[p2]      results/before_after_table.md (replacing [paste real output here])."
echo ""
echo "[p2] Tip — capture the whole run to a text file:"
echo "[p2]   bash portfolio-2-query-optimisation/run_p2.sh 2>&1 | tee p2_output.txt"
echo ""
echo "[p2] Git commit (from repo root):"
echo "    git add portfolio-2-query-optimisation/ && \\"
echo "    git commit -m 'feat(p2): 9 queries + EXPLAIN ANALYZE before/after indexes' && \\"
echo "    git tag p2-queries"
echo "==================================================================="
