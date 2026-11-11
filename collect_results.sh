#!/usr/bin/env bash
# collect_results.sh — gather the key REAL numbers from your own run into
# my_results.txt. Run from the repo root after all five portfolios have run:
#   bash collect_results.sh && code my_results.txt
cd "$(dirname "$0")"
OUT=my_results.txt
PSQL="sudo runuser -u postgres -- psql -d testpoint -X -q"
P1=portfolio-1-database-design; P2=portfolio-2-query-optimisation
P3=portfolio-3-transactions-concurrency; P4=portfolio-4-nosql; P5=portfolio-5-distributed-cloud
{
echo "MY RESULTS — TestPoint CBT — $(date '+%Y-%m-%d %H:%M %Z')"
echo
echo "===== P1: bulk data + row counts ====="
grep -E "^ (candidates|sessions|seat allocations|payments|results|session date span|upcoming sessions) " $P1/p1_output.log 2>/dev/null
$PSQL -c "SELECT 'candidate' t, count(*) FROM candidate UNION ALL SELECT 'exam_session', count(*) FROM exam_session
          UNION ALL SELECT 'seat_allocation', count(*) FROM seat_allocation UNION ALL SELECT 'payment', count(*) FROM payment
          UNION ALL SELECT 'result', count(*) FROM result UNION ALL SELECT 'seat', count(*) FROM seat;"
echo "===== P1: constraint tests ====="
grep -E "^ T[0-9]+\.|^Result:" $P1/p1_output.log 2>/dev/null || echo "(no p1_output.log)"
echo
echo "===== P2: BEFORE / AFTER timings ====="
sed -n '/SUMMARY/,/DONE/p' $P2/p2_output.log 2>/dev/null | grep -E "sql|Query" || echo "(no p2_output.log)"
echo "--- Q9 plans ---"
for f in before after; do echo "[$f]"; sed -n '/09_candidate_history/,$p' $P2/results/explain_$f.txt 2>/dev/null | grep -E "Scan on (result|payment)|Index Scan using idx_(result|payment)|Bitmap Index Scan" | head -3; done
echo
echo "===== P3: commit / rollback + race demos ====="
sed -n '/BEFORE — rows/,/Conclusion/p' $P3/p3_output.log 2>/dev/null | grep -E "DEMO|ERROR:|UNCHANGED|still free|rows_holding|^ +[0-9]+ +\| +[0-9]+ +\| +[0-9]+ *$|^ +[0-9]+ *$"
grep -E "PART|ERROR \[|>>>" $P3/race_demos_output.log 2>/dev/null || echo "(no race_demos_output.log)"
echo
echo "===== P4: MongoDB ====="
grep -E "PASS|FAIL|questions        :|attempts         :|Stage|Docs  |Time ms" $P4/p4_output.log 2>/dev/null || echo "(no p4_output.log)"
echo
echo "===== P5: partitions + pruning ====="
sed -n '/Rows per partition/,$p' $P5/partition_output.log 2>/dev/null | sed '/WITHOUT date filter/,/WITH a one-month filter/{/Seq Scan on seat_allocation_part_/d}' | grep -v -e '^ *$' -e '^-*+' | head -60
echo "===== P5: replica ====="
grep -v -e '^ *$' -e '^-*+' $P5/replication_output.log 2>/dev/null | grep -E "PRIMARY|REPLICA|read-only|P5-REPLICA|streaming|recovery| f$| t$|replay_lag|0 *$" | head -30
echo
echo "===== GitHub ====="
git remote get-url origin 2>&1
git log --oneline 2>&1 | head -12
} > "$OUT" 2>&1
echo "Saved $OUT — open it with:  code $OUT"
