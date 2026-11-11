# Portfolio 1 — Normalisation notes (1NF → 2NF → 3NF)

This document walks each of the 9 TestPoint CBT tables through the three
normal forms and shows why the final schema is in **3NF**. The aim of
normalisation, as set out in Study Session 1 of the MIT 8103 course notes
(*Review of Traditional Relational Databases and Advanced Concepts*), is to
remove redundancy and update anomalies so that each fact is stored in exactly
one place.

## Definitions used

- **1NF** — every column holds atomic values; every row has a unique
  identifier (a primary key); no repeating groups.
- **2NF** — already 1NF, AND every non-key attribute depends on the **whole**
  primary key (relevant for composite keys). Removes partial dependencies.
- **3NF** — already 2NF, AND no non-key attribute depends on another non-key
  attribute ("nothing but the key"). Removes transitive dependencies.

## Why the schema is in 3NF table-by-table

| Table | PK | Non-key attrs | 2NF check | 3NF check |
|---|---|---|---|---|
| `centre` | `centre_id` | code, name, city, address, seat_capacity, created_at | Single-column PK ⇒ 2NF trivially | `seat_capacity` is a fact about the centre itself, not about any other attribute ⇒ 3NF |
| `exam` | `exam_id` | code, title, body, category, duration_minutes, default_fee, created_at | Single-column PK ⇒ 2NF | `default_fee` is set by the exam body for that exam, independent of where/when it runs ⇒ 3NF |
| `exam_session` | `session_id` | centre_id, exam_id, session_date, start_time, end_time, session_range, fee, status | Single-column surrogate PK ⇒ 2NF | `fee` could vary per session (rescheduled pricing), so it lives here and not on `exam`; `session_range` is derived from start/end time but is materialised because the EXCLUDE constraint needs a GiST index on it — this is a deliberate denormalisation documented below |
| `seat` | `seat_id` | centre_id, seat_number, computer_name, status | Single-column PK ⇒ 2NF | `computer_name` is the inventory hostname of that exact seat, not derivable from centre ⇒ 3NF |
| `candidate` | `candidate_id` | first_name, last_name, email, phone, gender, state_of_origin | Single-column PK ⇒ 2NF | No transitive chain — `state_of_origin` is a fact about the candidate, not about email or phone ⇒ 3NF |
| `registration` | `registration_id` | candidate_id, exam_id, registered_at, status | Single-column surrogate PK ⇒ 2NF | `status` depends on the registration lifecycle, not on candidate or exam alone ⇒ 3NF |
| `seat_allocation` | `allocation_id` | session_id, seat_id, candidate_id, registration_id, session_range, allocated_at, checked_in, attended | Surrogate PK ⇒ 2NF | `session_range` is **copied** from `exam_session` to let the EXCLUDE GiST constraint live on a single table — see "deliberate denormalisation" below |
| `payment` | `payment_id` | registration_id, amount, paid_at, status, reference | Surrogate PK ⇒ 2NF | `amount` is set at payment time; `reference` is the PSP transaction id, unique to this payment ⇒ 3NF |
| `result` | `result_id` | allocation_id (UNIQUE FK), candidate_id, exam_id, score, graded_at | Surrogate PK ⇒ 2NF | `score` is a fact about one specific sitting (allocation), so the FK to `allocation_id` is the right place; `candidate_id`/`exam_id` are repeated for reporting convenience but are functionally dependent on `allocation_id` (each allocation maps to exactly one candidate + one exam) ⇒ 3NF |

## Composite keys vs. surrogate keys

A purist 3NF design for `seat_allocation` would use the composite key
**(`session_id`, `seat_id`)** (one seat per session, so this pair is unique)
and drop `allocation_id`. We keep a surrogate `allocation_id BIGSERIAL`
because:

1. **Foreign keys** — `result.allocation_id` and the EXCLUDE constraint both
   reference a single-column key, which is cheaper to index.
2. **ORM / application convenience** — every row has a stable handle even if
   a seat is reassigned.

Surrogate keys do not violate 3NF as long as the natural key is still
enforced, which it is: `UNIQUE (seat_id, session_id)`.

## Deliberate denormalisations (documented)

| Denormalisation | Where | Why |
|---|---|---|
| `session_range tstzrange` copied onto `seat_allocation` | `seat_allocation.session_range` | A GiST `EXCLUDE` constraint can only operate on columns of the table it is defined on. Without copying the range, we would have to enforce "candidate cannot be in two overlapping sessions" with a trigger that joins to `exam_session` on every insert — slow on a 50k+ table. Copying the range into the table lets PostgreSQL's GiST index enforce the rule in O(log n). The `trg_sync_session_range` trigger keeps the copy in sync. |
| `result.candidate_id`, `result.exam_id` repeated | `result` | Each is functionally dependent on `allocation_id` (one allocation → one candidate + one exam). They are duplicated so Portfolio 2's pass-rate and per-exam queries can aggregate without joining two extra tables. This is a **read-optimised 3NF** pattern: 3NF is preserved because the redundancy is functional, not transitive. |
| `exam_session.fee` even though `exam.default_fee` exists | `exam_session` | The fee advertised for a re-sit / late-booking session can differ from the exam's default fee. Keeping both lets the bulk generator vary the fee while still defaulting new exams to a sensible number. |

## What we explicitly did NOT do (anomalies avoided)

- We did **not** store `centre.city` on `exam_session` — that would be a
  transitive dependency (`session → centre → city`). To report by city we
  join `exam_session → centre`, which is the correct 3NF path.
- We did **not** store the candidate's name on `seat_allocation` — names are
  in `candidate`, joined by `candidate_id`.
- We did **not** store the payment amount on `registration` — `payment` is
  its own table so a failed+retried payment produces two rows, not an
  in-place update that loses history.

## Conclusion

The schema satisfies 3NF for all nine tables. The two materialised
redundancies (`session_range` on `seat_allocation`, and `candidate_id` +
`exam_id` on `result`) are intentional, functional, and kept in sync by
constraints/triggers; they are read-optimisations, not transitive
dependencies, so they do not introduce update anomalies.
