# Portfolio 2 — Query Processing and Optimisation

**Portfolio:** 2 · **Marks:** 7 · **Study session covered:** Study Session 4
(*Query Optimisation in Database*: introduction to queries, query
optimisation, query execution plans and cost estimation, file organisation).

## What this portfolio demonstrates

Eight reporting queries against the TestPoint CBT database populated by
Portfolio 1, each run with `EXPLAIN ANALYZE` **before** and **after** a set of
optimisation indexes is added. The before/after plans and execution times are
captured and pasted into `results/before_after_table.md`.

| # | Query | Business question |
|---|---|---|
| Q1 | Free seats at a centre for a session | "Which computers can I still book?" |
| Q2 | Candidates per exam per month | "Which exams are growing / shrinking?" |
| Q3 | Centre utilisation % | "Are our centres over- or under-used?" |
| Q4 | Pass rate per exam | "Which exams do candidates find hardest?" |
| Q5 | No-show rate per centre | "How many paid seats went empty on exam day?" |
| Q6 | Revenue per centre | "Which centre earns the most?" |
| Q7 | Top exams by revenue (bonus) | "Which exam bodies should we prioritise?" |
| Q8 | Allocations by start-hour (bonus) | "When is peak demand — morning or afternoon?" |
| Q9 | One candidate's exam history (help-desk lookup) | "Show me every exam this candidate took, the score and payment" |

## How to run (Codespaces)

```bash
# 1. Portfolio 1 must already have been run (database + 50k+ rows).
bash portfolio-2-query-optimisation/run_p2.sh
# 2. Capture the whole run to a text file so you can paste plans:
bash portfolio-2-query-optimisation/run_p2.sh 2>&1 | tee p2_output.txt
```

`run_p2.sh` does, in order:

1. Drops any pre-existing optimisation indexes (clean BEFORE state).
2. Runs all 9 queries with `EXPLAIN ANALYZE` (BEFORE).
3. Applies `indexes/create_indexes.sql`.
4. Runs all 9 queries with `EXPLAIN ANALYZE` again (AFTER).

## Indexes added (`indexes/create_indexes.sql`)

| Index | Targets |
|---|---|
| `idx_sa_session_id`        | Q1, Q3, Q8 — join `seat_allocation → exam_session` |
| `idx_sa_candidate_id`      | Q2 — `count(DISTINCT candidate_id)` |
| `idx_es_exam_id`           | Q2, Q7 — join `exam_session → exam` |
| `idx_es_centre_id`         | Q3, Q6 — join `exam_session → centre` |
| `idx_es_session_date`      | Q2 — `date_trunc('month', session_date)` |
| `idx_result_exam_id`       | Q4 — join `result → exam` |
| `idx_payment_registration_id` | Q6, Q7 — join `payment → registration` |
| `idx_payment_success_amount`  | Q6, Q7 — partial covering index (`WHERE status='success'` INCLUDE amount) |

## What to screenshot (for the LMS evidence)

| Screenshot | Where it comes from |
|---|---|
| BEFORE EXPLAIN ANALYZE × 8 | `run_p2.sh` BEFORE pass |
| Index list after creation | `create_indexes.sql` final `SELECT … FROM pg_indexes` |
| AFTER EXPLAIN ANALYZE × 8  | `run_p2.sh` AFTER pass |
| Filled-in before/after table | `results/before_after_table.md` after you paste real output |

## Git commit (from repo root)

```bash
git add portfolio-2-query-optimisation/ && \
git commit -m "feat(p2): 9 queries + EXPLAIN ANALYZE before/after indexes" && \
git tag p2-queries
```

## Plain-English explanation

This portfolio answers **"can you read and improve a query plan?"** The eight
queries are real TestPoint reporting needs — free seats, utilisation, pass
rate, no-show rate, revenue. Each is run twice with `EXPLAIN ANALYZE`: once
with only the PK/UNIQUE/EXCLUDE indexes from Portfolio 1, and once after
adding B-tree indexes on the hot join and filter columns. The student fills
`results/before_after_table.md` with the **real** plans and `Execution Time`
lines from each run — no values are invented.

The partial covering index `idx_payment_success_amount` is the interesting
one: because every revenue query filters on `payment.status = 'success'` and
reads `amount`, a partial index `ON payment(amount) INCLUDE (registration_id)
WHERE status = 'success'` lets PostgreSQL answer those queries with an
`Index Only Scan` — the heap is never touched.

This portfolio maps directly to **Study Session 4** of the MIT 8103 course
notes, which covers query optimisation, execution plans and cost estimation.


## Honest analysis (what the real numbers show)

`run_p2.sh` saves the full plans in `results/explain_before.txt` and
`results/explain_after.txt` and prints a BEFORE / AFTER / speed-up table.

* **Q9 (one candidate's history) is where indexes pay off**: before, PostgreSQL
  reads every row of `result` and `payment` to find one candidate's ~20; after
  `idx_result_candidate_id` and `idx_payment_registration_id` it reads only those.
* **Q2–Q8 are reports** that read most of the table (two years of data), so the
  planner correctly keeps sequential scans + hash joins and their times stay
  about the same (small changes are run-to-run noise). An index helps when a
  query reads a small fraction of the rows.
* **Q1 (free seats)** is already fast before, because Portfolio 1 indexes
  `seat_allocation(session_id)` (the capacity trigger needs it).
