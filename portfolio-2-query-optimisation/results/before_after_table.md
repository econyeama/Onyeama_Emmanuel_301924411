# Portfolio 2 — EXPLAIN ANALYZE: before / after indexes

> **Honesty rule:** every `[paste real output here]` placeholder below MUST be
> replaced with the EXPLAIN ANALYZE output you actually captured from your
> Codespaces run. Do **not** invent numbers, never copy a plan from the
> internet. The lecturer may select you for a verification discussion.

## How the before/after comparison is produced

`run_p2.sh` runs the sequence:

1. **BEFORE** — run all 8 queries with EXPLAIN ANALYZE on a database that has
   only PK / UNIQUE / EXCLUDE indexes (no extra B-tree indexes).
   Capture each plan.
2. `indexes/create_indexes.sql` — add the optimisation indexes.
3. **AFTER** — re-run all 9 queries with EXPLAIN ANALYZE.
   Capture each plan.

For each query the table below summarises:

| Field | Meaning |
|---|---|
| Plan (before) | The full EXPLAIN ANALYZE tree before indexes |
| Plan (after)  | The full EXPLAIN ANALYZE tree after indexes |
| Execution time (before) | The `Execution Time: X ms` line from the before plan |
| Execution time (after)  | The same line from the after plan |
| Speed-up | `before / after` (≥ 1 means the index helped) — `run_p2.sh` prints all of these at the end |
| Indexes used (after)    | The `Index Scan` / `Index Only Scan` node names |

---

## Q1 — Free seats at a centre for a session

**Plan (before):**
```
[paste real output here]
```

**Plan (after):**
```
[paste real output here]
```

| Metric | Before | After |
|---|---|---|
| Execution time (ms) | [paste real value] | [paste real value] |
| Speed-up | — | [paste real ratio] |
| Indexes used (after) | [paste real node names] |

---

## Q2 — Candidates per exam per month

**Plan (before):**
```
[paste real output here]
```

**Plan (after):**
```
[paste real output here]
```

| Metric | Before | After |
|---|---|---|
| Execution time (ms) | [paste real value] | [paste real value] |
| Speed-up | — | [paste real ratio] |
| Indexes used (after) | [paste real node names] |

---

## Q3 — Centre utilisation %

**Plan (before):**
```
[paste real output here]
```

**Plan (after):**
```
[paste real output here]
```

| Metric | Before | After |
|---|---|---|
| Execution time (ms) | [paste real value] | [paste real value] |
| Speed-up | — | [paste real ratio] |
| Indexes used (after) | [paste real node names] |

---

## Q4 — Pass rate per exam

**Plan (before):**
```
[paste real output here]
```

**Plan (after):**
```
[paste real output here]
```

| Metric | Before | After |
|---|---|---|
| Execution time (ms) | [paste real value] | [paste real value] |
| Speed-up | — | [paste real ratio] |
| Indexes used (after) | [paste real node names] |

---

## Q5 — No-show rate per centre

**Plan (before):**
```
[paste real output here]
```

**Plan (after):**
```
[paste real output here]
```

| Metric | Before | After |
|---|---|---|
| Execution time (ms) | [paste real value] | [paste real value] |
| Speed-up | — | [paste real ratio] |
| Indexes used (after) | [paste real node names] |

---

## Q6 — Revenue per centre

**Plan (before):**
```
[paste real output here]
```

**Plan (after):**
```
[paste real output here]
```

| Metric | Before | After |
|---|---|---|
| Execution time (ms) | [paste real value] | [paste real value] |
| Speed-up | — | [paste real ratio] |
| Indexes used (after) | [paste real node names] |

---

## Q7 — Top exams by revenue

**Plan (before):**
```
[paste real output here]
```

**Plan (after):**
```
[paste real output here]
```

| Metric | Before | After |
|---|---|---|
| Execution time (ms) | [paste real value] | [paste real value] |
| Speed-up | — | [paste real ratio] |
| Indexes used (after) | [paste real node names] |

---

## Q8 — Allocations by start-hour (peak-hours)

**Plan (before):**
```
[paste real output here]
```

**Plan (after):**
```
[paste real output here]
```

| Metric | Before | After |
|---|---|---|
| Execution time (ms) | [paste real value] | [paste real value] |
| Speed-up | — | [paste real ratio] |
| Indexes used (after) | [paste real node names] |

---

## Summary table (fill in after both runs)

| Query | Before (ms) | After (ms) | Speed-up | Key index that helped |
|---|---|---|---|---|
| Q1 free seats              | [paste] | [paste] | [paste] | [paste] |
| Q2 candidates per exam/mo  | [paste] | [paste] | [paste] | [paste] |
| Q3 centre utilisation      | [paste] | [paste] | [paste] | [paste] |
| Q4 pass rate               | [paste] | [paste] | [paste] | [paste] |
| Q5 no-show rate            | [paste] | [paste] | [paste] | [paste] |
| Q6 revenue per centre      | [paste] | [paste] | [paste] | [paste] |
| Q7 top exams by revenue    | [paste] | [paste] | [paste] | [paste] |
| Q8 peak hours              | [paste] | [paste] | [paste] | [paste] |

## Brief performance analysis (write this AFTER both runs)

> Use this space to write 2–3 paragraphs on which queries benefited most,
> which did not (and why — e.g. full-table aggregation queries often cannot
> avoid a Seq Scan), and what the planner chose differently. Reference the
> real node names (`Seq Scan`, `Index Scan`, `Index Only Scan`, `Hash Join`,
> `Nested Loop`, `Gather Merge`) you saw in your captured plans.

[paste your real analysis here]
