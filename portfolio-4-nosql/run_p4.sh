#!/usr/bin/env bash
# =============================================================================
# Portfolio 4 — run_p4.sh
# TestPoint CBT — NoSQL (MongoDB) question bank.
#
# Steps:
#   1. Create collections (js/01_create_collection.js).
#   2. Install the JSON schema validator + test valid/invalid inserts (js/02).
#   3. Insert a small readable seed (js/03_seed_small.js) — optional, the bulk
#      generator below replaces it.
#   4. Bulk-generate 42,000 questions + ~120,000 attempts (Python).
#   5. Run the aggregations (js/04_aggregations.js).
#   6. Run the COLLSCAN → IXSCAN index demo (js/05_index_demo.js).
#
# Codespaces rule: MongoDB is bound to 127.0.0.1:27017 by setup.sh.
# =============================================================================
set -euo pipefail

PORTFOLIO_DIR="$(cd "$(dirname "$0")" && pwd)"
MONGO_URL="${MONGO_URL:-mongodb://127.0.0.1:27017}"
MONGO_DB="${MONGO_DB:-testpoint}"

echo "==================================================================="
echo " Portfolio 4 — NoSQL (MongoDB) question bank (TestPoint CBT)"
echo "==================================================================="

echo "[p4] waiting for MongoDB to accept connections"
for i in $(seq 1 30); do
    if mongosh --quiet --eval "db.runCommand({ping:1}).ok" "${MONGO_URL}" 2>/dev/null | grep -q 1; then
        break
    fi
    sleep 1
done

echo "[p4] step 1 — create collections"
mongosh "${MONGO_URL}/${MONGO_DB}" --quiet \
        --file "${PORTFOLIO_DIR}/js/01_create_collection.js"

echo ""
echo "[p4] step 2 — install JSON schema validator + valid/invalid tests"
mongosh "${MONGO_URL}/${MONGO_DB}" --quiet \
        --file "${PORTFOLIO_DIR}/js/02_schema_validation.js"

echo ""
echo "[p4] step 3 — small readable seed (optional, replaced by bulk below)"
mongosh "${MONGO_URL}/${MONGO_DB}" --quiet \
        --file "${PORTFOLIO_DIR}/js/03_seed_small.js"

echo ""
echo "[p4] step 4 — bulk generate 42,000 questions + ~120,000 attempts"
MONGO_URL="${MONGO_URL}" MONGO_DB="${MONGO_DB}" python3 \
    "${PORTFOLIO_DIR}/bulk_data/generate_questions.py"

echo ""
echo "[p4] step 5 — aggregations"
mongosh "${MONGO_URL}/${MONGO_DB}" --quiet \
        --file "${PORTFOLIO_DIR}/js/04_aggregations.js"

echo ""
echo "[p4] step 6 — COLLSCAN → IXSCAN index demo"
mongosh "${MONGO_URL}/${MONGO_DB}" --quiet \
        --file "${PORTFOLIO_DIR}/js/05_index_demo.js"

echo ""
echo "[p4] DONE."
echo "[p4] What to screenshot:"
echo "[p4]   1. The validator tests (valid MCQ/TF/FI/SA accepted; invalid ones rejected)."
echo "[p4]   2. The MONGODB BULK DATA SUMMARY block from generate_questions.py."
echo "[p4]   3. The aggregation outputs (A1 subject×difficulty, A2 avg score per question,"
echo "[p4]      A3 pass rate per subject, A4 type distribution per exam body)."
echo "[p4]   4. The index demo output: winningPlan.stage COLLSCAN vs IXSCAN,"
echo "[p4]      totalDocsExamined BEFORE vs AFTER, executionTimeMillis BEFORE vs AFTER."
echo "[p4]   5. db.questions.getIndexes() output."
echo ""
echo "[p4] Git commit (from repo root):"
echo "    git add portfolio-4-nosql/ && \\"
echo "    git commit -m 'feat(p4): MongoDB question bank, schema validation, 42k docs, aggregations, COLLSCAN->IXSCAN' && \\"
echo "    git tag p4-nosql"
echo "==================================================================="
