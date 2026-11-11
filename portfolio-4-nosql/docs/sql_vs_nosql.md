# Portfolio 4 — SQL vs NoSQL comparison (TestPoint CBT)

This portfolio uses **PostgreSQL** (SQL) for the transactional core of
TestPoint CBT — centres, sessions, seats, allocations, payments, results —
and **MongoDB** (NoSQL) for the **question bank**, because the question bank
contains documents of four genuinely different shapes (multiple choice,
true/false, fill-in, short-answer) plus optional images, tags and metadata
that would be painful to model in a fixed-column relational schema.

This document compares the two on the dimensions the MIT 8103 course notes
(Study Sessions 1, 3 and 5) emphasise.

## 1. Data model

| Dimension | PostgreSQL (SQL) | MongoDB (NoSQL document) |
|---|---|---|
| Unit of storage | Row in a strictly-typed table | JSON-like document (BSON) in a collection |
| Schema | Rigid, declared up front (DDL); changes need migrations | Flexible; per-document shape can vary; a `$jsonSchema` validator can enforce a discriminated union |
| Relationships | Foreign keys + joins; normalisation reduces redundancy | Embedding (denormalised) by default; `$lookup` for occasional joins |
| Query language | SQL (declarative, standardised) | MQL / aggregation pipeline (imperative-ish stages) |
| ACID | Always (MVCC + WAL) | Per-document atomic; multi-document transactions supported since 4.0 but heavier |
| Indexes | B-tree (default), GiST, GIN, BRIN, hash, partial, covering | B-tree, compound, text, geospatial, hashed, TTL, wildcard |
| Scale model | Scale-up by default; sharding via extensions (citrus, pg_partman for partitioning) | Native horizontal sharding by shard key |

## 2. Why the question bank is a NoSQL fit

A TestPoint question is naturally a **document**:

```js
// MCQ
{ type: "mcq", subject: "Mathematics", topic: "Geometry", difficulty: "hard",
  question: "A circle has radius 7. What is its area (π = 22/7)?",
  options: ["44","154","49","308"], correct_index: 1,
  _metadata: { exam_body: "WAEC", image_url: "...", tags: ["circle","area"], ... } }

// True/false — different shape
{ type: "true_false", subject: "Current Affairs", topic: "Geography",
  difficulty: "easy", question: "Lagos was the capital of Nigeria until 1991.",
  correct_answer: true, _metadata: { ... } }

// Fill-in — yet another shape
{ type: "fill_in", subject: "English Language", topic: "Vocabulary",
  difficulty: "easy", question: "The capital of Nigeria is ____.",
  acceptable_answers: ["Abuja","abuja","ABUJA"], case_sensitive: false, ... }

// Short-answer with image — fourth shape
{ type: "short_answer", subject: "Project Management", topic: "Risk",
  difficulty: "hard", question: "Explain the difference between a risk and an issue.",
  model_answer: "...", marks: 5,
  _metadata: { exam_body: "PMP", image_url: "...", tags: ["risk","issues"], ... } }
```

The four shapes have **different required fields**. In SQL you would need
either:

- **Single-table with nullable columns** (`correct_index`, `correct_answer`,
  `acceptable_answers`, `model_answer`, `marks` all NULL for most rows) —
  wastes space, no protection against an MCQ row accidentally having a
  `correct_answer` column filled in.
- **Table-per-type inheritance** (`questions` parent + `mcq_questions`,
  `tf_questions`, … children) — correct but heavy: four child tables, four
  sets of foreign keys, and every reporting query needs `UNION ALL`.
- **EAV (entity-attribute-value)** — an anti-pattern that breaks the query
  planner.

MongoDB's `$jsonSchema` validator with `oneOf` solves this cleanly: the
`type` field discriminates the shape, and the validator enforces that an MCQ
has `options` + `correct_index`, a true/false has `correct_answer`, etc. The
collection holds 42,000 heterogeneous documents in one place, and the
aggregation pipeline can still group/filter them by any field.

## 3. Why the transactional core stays in SQL

The seat-allocation side of TestPoint has **hard relational integrity**:

- A seat belongs to exactly one centre.
- A session is at one centre, of one exam, in one time window.
- A candidate cannot be on two seats in the same session (UNIQUE).
- A candidate cannot be in two overlapping sessions (EXCLUDE on a tstzrange).
- A session cannot exceed its centre's seat capacity (trigger).
- A payment must have `amount > 0` (CHECK).

These rules are **multi-row constraints** that depend on joins between
tables and on PostgreSQL-specific extensions (`btree_gist` for the EXCLUDE
constraint, triggers for capacity). MongoDB's per-document atomicity and its
`$jsonSchema` validator cannot express "this candidate is not already in an
overlapping session" without an application-level lock or a multi-document
transaction. SQL is the right tool here.

## 4. ACID vs BASE / CAP (Study Session 2)

| | SQL (PostgreSQL) | NoSQL (MongoDB) |
|---|---|---|
| Consistency model | Strict (ACID); serialisable if needed | tunable read/write concern; "eventual" by default at scale |
| Atomicity unit | Transaction across any number of rows/tables | Single document atomic by default; multi-doc txn available but heavier |
| Availability under partition | Stays consistent, may refuse writes if the primary is unreachable | Replica set elects a new primary; writes can continue (availability) at the cost of some staleness |
| Use in this portfolio | The seat-allocation transactional core (P1, P2, P3) | The question bank, which is read-mostly and benefits from flexible schema (P4) |

## 5. Performance and scaling

- **PostgreSQL** excels at complex joins, aggregations with `GROUP BY`, and
  constraints. It scales up well; for the TestPoint workload (50k+
  allocations across 2 years) the B-tree indexes in Portfolio 2 take query
  times from full Seq Scan to Index Scan.
- **MongoDB** excels at flexible-schema reads and at sharding by a chosen
  shard key. The 42,000-document question bank is a single collection that
  can be sharded by `subject` if it grows past a single node; reads of
  "hard Mathematics questions" go from COLLSCAN to IXSCAN after the
  `{subject: 1, difficulty: 1}` compound index (see `js/05_index_demo.js`).

## 6. Suitability verdict for TestPoint CBT

| Subsystem | Best fit | Why |
|---|---|---|
| Centres, exams, sessions, seats, candidates, registrations, allocations, payments, results | **PostgreSQL** | Multi-row constraints (UNIQUE, EXCLUDE on tstzrange, capacity trigger), strict ACID, money |
| Question bank | **MongoDB** | Heterogeneous document shapes; flexible metadata; read-mostly; schema validation via `$jsonSchema` oneOf |
| Exam-day attempts (per-candidate, per-question scoring) | **MongoDB** (attempts collection) | High write throughput, append-only, naturally document-shaped; mirrors the questions collection |

## 7. Sources / course-note alignment

- MIT 8103 Study Session 1 — Review of Traditional Relational Databases and
  Advanced Concepts (ACID, normalisation, DBMS characteristics) → the SQL
  side of TestPoint.
- MIT 8103 Study Session 3 — Big Data and Cloud Database Systems (cloud DB
  use cases) → the NoSQL scaling story.
- MIT 8103 Study Session 5 — Emerging Trends in Database Systems (graph
  databases, the wider NoSQL family) → context for the document-store
  choice for the question bank.
- MongoDB documentation — `$jsonSchema` oneOf, compound B-tree indexes,
  `explain("executionStats")` COLLSCAN vs IXSCAN.
