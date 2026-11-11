# Portfolio 4 — NoSQL and Advanced Data Models

**Portfolio:** 4 · **Marks:** 7 · **Study session covered:** Study Session 3
(*Big Data and Cloud Database Systems*) + Study Session 5 (*Emerging Trends
in Database Systems*: graph/document databases and the NoSQL family).

## What this portfolio demonstrates

A MongoDB **question bank** for TestPoint CBT that holds questions of four
genuinely different shapes, plus an **attempts** collection that records
every candidate's score on every question they tried.

| Concept | File |
|---|---|
| Create `questions` + `attempts` collections | `js/01_create_collection.js` |
| `$jsonSchema` validator with `oneOf` (discriminated union on `type`) + valid/invalid insert tests | `js/02_schema_validation.js` |
| Small readable seed (one of each shape + a few attempts) | `js/03_seed_small.js` |
| Bulk generator: 42,000 questions + ~120,000 attempts | `bulk_data/generate_questions.py` |
| Aggregations: questions per subject/difficulty, avg score per question, pass rate per subject, type distribution per exam body | `js/04_aggregations.js` |
| COLLSCAN → IXSCAN index demo with `explain("executionStats")` | `js/05_index_demo.js` |
| SQL vs NoSQL comparison | `docs/sql_vs_nosql.md` |

## The four question shapes

| Type | Required fields (beyond the common ones) | Why it is a different shape |
|---|---|---|
| `mcq` | `options[]`, `correct_index` | Array of strings + integer index |
| `true_false` | `correct_answer` (bool) | Boolean scalar |
| `fill_in` | `acceptable_answers[]`, `case_sensitive` | Array of acceptable strings |
| `short_answer` | `model_answer`, `marks` | Long text + integer mark |

The `$jsonSchema` validator uses `oneOf` so that an MCQ must have `options`
+ `correct_index`, a true/false must have `correct_answer`, etc. An MCQ
missing `correct_index` is rejected at insert time (see the test in
`js/02_schema_validation.js`).

## How to run (Codespaces)

```bash
bash portfolio-4-nosql/run_p4.sh
```

The script:

1. Creates / resets the two collections.
2. Installs the validator and runs the valid/invalid insert tests.
3. Inserts the small seed.
4. Runs the Python bulk generator (42k questions + 120k attempts).
5. Runs the aggregations.
6. Runs the index demo (COLLSCAN then IXSCAN).

## What to screenshot (for the LMS evidence)

| Screenshot | Where it comes from |
|---|---|
| Validator tests (valid accepted, invalid rejected) | `js/02_schema_validation.js` |
| Bulk data summary (counts by type/difficulty/subject) | `generate_questions.py` |
| Aggregation outputs A1–A4 | `js/04_aggregations.js` |
| Index demo: winningPlan COLLSCAN → IXSCAN + totalDocsExamined + executionTimeMillis BEFORE/AFTER | `js/05_index_demo.js` |
| `db.questions.getIndexes()` | `js/05_index_demo.js` |

## Git commit (from repo root)

```bash
git add portfolio-4-nosql/ && \
git commit -m "feat(p4): MongoDB question bank, schema validation, 42k docs, aggregations, COLLSCAN->IXSCAN" && \
git tag p4-nosql
```

## Plain-English explanation

The TestPoint question bank is a textbook NoSQL fit: a question can be a
multiple-choice, a true/false, a fill-in-the-gap, or a short-answer, and
each shape has different required fields. Forcing that into a single
fixed-column SQL table would mean a row full of NULLs (wasteful and
error-prone), or four child tables (heavy to query), or an EAV
anti-pattern (breaks the planner).

MongoDB's `$jsonSchema` validator with `oneOf` discriminates the shape on
the `type` field, so the collection holds 42,000 heterogeneous documents in
one place and the validator still rejects malformed inserts. The
aggregation pipeline then groups by subject+difficulty, computes average
score per question (joining `attempts → questions` with `$lookup`), and
breaks down pass rate per subject. The index demo shows the same
Mathematics+hard filter going from a COLLSCAN of all 42,000 documents to
an IXSCAN of just the matching ones.

This maps to **Study Session 3** (big-data / cloud use cases — the
question bank scales horizontally by sharding on `subject`) and **Study
Session 5** (emerging trends — the document-store family of NoSQL). The
`docs/sql_vs_nosql.md` write-up explains why the **transactional core**
of TestPoint (seats, allocations, payments) stays in PostgreSQL while the
question bank is in MongoDB.
