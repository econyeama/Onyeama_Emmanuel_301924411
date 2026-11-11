# Portfolio 3 — Transactions and Concurrency

**Portfolio:** 3 · **Marks:** 7 · **Study session covered:** Study Session 1
(ACID within the traditional RDBMS) + Study Session 2 (CAP / ACID / BASE
trade-offs, which reappear when the same patterns are distributed in
Portfolio 5).

## What this portfolio demonstrates

| Concept | File / location |
|---|---|
| `allocate_seat()` transactional function (check seat → allocate → record payment) | `sql/01_allocate_seat_function.sql` |
| COMMIT / ROLLBACK — a failed payment cancels the allocation | `sql/02_commit_rollback_demo.sql` |
| Two-terminal "two candidates, one last seat" race condition: bug + fix 1 (UNIQUE) + fix 2 (SELECT FOR UPDATE) | `guides/race_condition_two_terminal.md` |
| Isolation levels: READ COMMITTED, REPEATABLE READ, SERIALIZABLE | `sql/03_isolation_levels.sql` (two-terminal procedure) |
| Classic A→B / B→A deadlock | `sql/04_deadlock_demo.sql` (two-terminal procedure) |

## How to run (Codespaces)

### Single-terminal parts (run by `run_p3.sh`)

```bash
bash portfolio-3-transactions-concurrency/run_p3.sh
```

This installs `allocate_seat()` and runs the COMMIT/ROLLBACK atomicity demo,
then prints the two-terminal instructions for the race-condition, isolation,
and deadlock demos.

### Interactive two-terminal parts

Open **two** codespace terminals side by side, each running:

```bash
sudo runuser -u postgres -- psql -d testpoint
```

Then follow, in order:

1. `guides/race_condition_two_terminal.md` — the bug, fix 1, fix 2.
2. `sql/03_isolation_levels.sql` — READ COMMITTED, REPEATABLE READ, SERIALIZABLE.
3. `sql/04_deadlock_demo.sql` — the A→B / B→A deadlock.

## The `allocate_seat()` function

`allocate_seat(p_session_id, p_candidate_id, p_seat_id, p_amount)` does, in
one atomic PL/pgSQL function call:

1. Validates the session exists.
2. Validates the seat exists, is `active`, and belongs to the session's centre.
3. Checks the seat is not already allocated in this session.
4. Checks the candidate is not already booked in this session.
5. Inserts a `registration` row (status = `allocated`).
6. Inserts a `seat_allocation` row (the capacity trigger + EXCLUDE constraint
   fire here as the final safety net).
7. Records a `payment` row — if `p_amount ≤ 0` it RAISEs, which rolls back
   the entire function call: no registration, no allocation, no payment.

Because a PL/pgSQL function runs inside the caller's transaction, the
raise-on-failed-payment pattern gives atomic allocate + pay: either both
happen or neither does.

## The race-condition walkthrough (the heart of this portfolio)

`guides/race_condition_two_terminal.md` walks through, with explicit terminal
commands for Terminal A and Terminal B:

1. **The bug** — a check-then-insert pattern on a table with no constraint
   lets both candidates grab the same seat. Result: two rows with the same
   `(seat_id, session_id)`.
2. **Fix 1** — `ALTER TABLE … ADD UNIQUE (seat_id, session_id)`. The second
   `INSERT` now fails with `SQLSTATE 23505` (duplicate key). Fail-fast; the
   application must catch and translate.
3. **Fix 2** — `SELECT seat_id … FROM seat WHERE seat_id = X FOR UPDATE`
   serialises concurrent allocations on the seat row itself. Terminal B
   **waits** for Terminal A to commit, then sees the seat is taken and
   raises a clear business message ("Seat … already booked … please pick
   another"). Queued rather than rejected; bounded by the first txn's
   duration.

The guide ends with a comparison table of the three approaches.

## What to screenshot (for the LMS evidence)

| Screenshot | Where it comes from |
|---|---|
| `allocate_seat()` self-test output | `run_p3.sh` |
| DEMO A COMMIT row counts (before/after) | `02_commit_rollback_demo.sql` |
| DEMO B ROLLBACK row counts (unchanged) + caught exception | `02_commit_rollback_demo.sql` |
| The bug: two rows with same (seat, session) | `race_condition_two_terminal.md` §1 |
| Fix 1: duplicate-key error in Terminal B | `race_condition_two_terminal.md` §2 |
| Fix 2: Terminal B blocked on `SELECT FOR UPDATE`, then clear message | `race_condition_two_terminal.md` §3 |
| SERIALIZABLE `SQLSTATE 40001` | `03_isolation_levels.sql` DEMO 3 |
| Deadlock `SQLSTATE 40P01` | `04_deadlock_demo.sql` |

## Git commit (from repo root)

```bash
git add portfolio-3-transactions-concurrency/ && \
git commit -m "feat(p3): allocate_seat txn, COMMIT/ROLLBACK, race condition guide, isolation, deadlock" && \
git tag p3-txn
```

## Plain-English explanation

This portfolio answers **"can you keep a database correct when two people do
the same thing at the same time?"** The TestPoint CBT business has a classic
hotspot: the last free computer in a session, with two candidates clicking
"book" at the same millisecond.

The `allocate_seat()` function bundles the check, the allocation and the
payment into one atomic unit, so a failed payment cannot leave an orphan
allocation. The two-terminal guide then deliberately reproduces the
double-booking bug on a table with no constraint, fixes it two different
ways (a `UNIQUE` constraint that fail-fasts at the DB layer, and a
`SELECT … FOR UPDATE` row lock that queues the second request), and
compares the trade-offs. Finally, the isolation-levels and deadlock demos
show how PostgreSQL's MVCC snapshot isolation and deadlock detector behave
under the three standard isolation levels.

This maps to **Study Session 1** (ACID within the traditional RDBMS) and
previews **Study Session 2** (CAP / ACID / BASE), because the same
check-then-insert race reappears — in a harder form — when the database is
replicated across regions in Portfolio 5.
