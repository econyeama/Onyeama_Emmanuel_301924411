# Portfolio 3 — Two-terminal concurrency demos (Parts 1–6)

**Student:** Emmanuel Onyeama · **Matric:** 2026/A/MIT/0876 · **Case:** TestPoint CBT

Two candidates — **Chiamaka Obi at the Lagos front desk (Terminal A)** and
**Yusuf Danladi on the online portal (Terminal B)** — try to book **the same
computer (seat)** in the same PMP exam session at the same moment.

| Part | What it shows | Result you should see |
|---|---|---|
| 1 | **The bug** — check-then-insert, no unique rule | both inserts succeed → 2 candidates on 1 computer |
| 2 | **Fix 1** — `UNIQUE (seat_id, session_id)` | B waits for A, then `duplicate key` (23505) |
| 3 | **Fix 2** — `allocate_seat()` locks the seat row with `SELECT … FOR UPDATE` | B waits, then `allocate_seat: seat … is already allocated` |
| 4 | **Fix 3** — `SERIALIZABLE` isolation, still no unique rule | B's COMMIT fails: `could not serialize access` (40001) |
| 5 | READ COMMITTED vs REPEATABLE READ | the seat count changes mid-transaction under RC, not under RR |
| 6 | **Deadlock** — two desks lock two seats in opposite order | one gets `deadlock detected` (40P01); fix = lock in id order |

You can do this two ways. **Both produce real output from your own database.**

---

## Option 1 (fast) — run all six parts automatically

```bash
cd portfolio-3-transactions-concurrency
python3 run_race_demos.py | tee race_demos_output.log
```

`run_race_demos.py` opens **two real database sessions at once** (Terminal A
and Terminal B), sends every step below to the right session in the right
order, and prints what PostgreSQL answered. Steps that must wait for a lock
run in the background so you can see "still WAITING" and then the result.
Save `race_demos_output.log` — it is your evidence for Parts 1–6.

---

## Option 2 (by hand) — two terminal tabs

### Once, in either terminal

```bash
cd portfolio-3-transactions-concurrency
sudo runuser -u postgres -- psql -d testpoint -f sql/01_allocate_seat_function.sql
sudo runuser -u postgres -- psql -d testpoint -f sql/race_setup.sql
```

`race_setup.sql` creates a demo PMP session 45 days ahead, the three demo
candidates and the `seat_allocation_bug` table (a copy with **no** unique
rule). Re-run it any time to start again from clean.

### In EACH of the two terminals

Open two terminal tabs (the **+** next to the terminal's name). In each one:

```bash
cd portfolio-3-transactions-concurrency
sudo runuser -u postgres -- psql -d testpoint
```

then, inside psql:

```sql
\i sql/race_vars.sql
```

This loads `:sess`, `:ca` (Chiamaka), `:cb` (Yusuf), `:cc` (Grace), `:seat`,
`:seat2`, `:seat3` and `:fee` into **that** psql session, so every line below
can be pasted exactly as written — no ids to copy.

> Do the steps **in number order**, one line at a time, in the terminal shown.
> "(waits…)" means the cursor hangs: that is the lock working. Go to the next
> step in the *other* terminal and it will finish.

---

### Part 1 — THE BUG

| Step | Terminal | Paste this | What you see |
|---|---|---|---|
| 1 | A | `BEGIN;` | BEGIN |
| 2 | A | `SELECT count(*) FROM seat_allocation_bug WHERE session_id = :sess AND seat_id = :seat;` | 0 — seat looks free |
| 3 | B | `BEGIN;` | BEGIN |
| 4 | B | `SELECT count(*) FROM seat_allocation_bug WHERE session_id = :sess AND seat_id = :seat;` | 0 — free to B too |
| 5 | A | `INSERT INTO seat_allocation_bug (session_id, seat_id, candidate_id) VALUES (:sess, :seat, :ca);` | INSERT 0 1 |
| 6 | A | `COMMIT;` | COMMIT |
| 7 | B | `INSERT INTO seat_allocation_bug (session_id, seat_id, candidate_id) VALUES (:sess, :seat, :cb);` | INSERT 0 1 — nothing stops it |
| 8 | B | `COMMIT;` | COMMIT |
| 9 | A | `SELECT * FROM seat_allocation_bug WHERE session_id = :sess;` | **2 rows, same seat** ← the bug |

### Part 2 — FIX 1: a UNIQUE index

| Step | Terminal | Paste this | What you see |
|---|---|---|---|
| 1 | A | `TRUNCATE seat_allocation_bug;` | |
| 2 | A | `CREATE UNIQUE INDEX bug_seat_unique ON seat_allocation_bug (seat_id, session_id);` | CREATE INDEX |
| 3 | A | `BEGIN;` | |
| 4 | B | `BEGIN;` | |
| 5 | A | `INSERT INTO seat_allocation_bug (session_id, seat_id, candidate_id) VALUES (:sess, :seat, :ca);` | INSERT 0 1 |
| 6 | B | `INSERT INTO seat_allocation_bug (session_id, seat_id, candidate_id) VALUES (:sess, :seat, :cb);` | **(waits…)** |
| 7 | A | `COMMIT;` | B now shows `ERROR: duplicate key value violates unique constraint "bug_seat_unique"` |
| 8 | B | `ROLLBACK;` | |

### Part 3 — FIX 2: `allocate_seat()` with `SELECT … FOR UPDATE`

`allocate_seat()` (sql/01_allocate_seat_function.sql) locks the seat's row
with `SELECT … FOR UPDATE`, so two bookings of the same computer queue up.

| Step | Terminal | Paste this | What you see |
|---|---|---|---|
| 1 | A | `BEGIN;` | |
| 2 | A | `SELECT allocate_seat(:sess, :ca, :seat, :fee);` | an allocation_id |
| 3 | B | `BEGIN;` | |
| 4 | B | `SELECT allocate_seat(:sess, :cb, :seat, :fee);` | **(waits…)** on the seat lock |
| 5 | A | `COMMIT;` | B now shows `ERROR: allocate_seat: seat … is already allocated in session …` |
| 6 | B | `ROLLBACK;` | |

### Part 4 — FIX 3: SERIALIZABLE (no unique index at all)

| Step | Terminal | Paste this | What you see |
|---|---|---|---|
| 1 | A | `DROP INDEX bug_seat_unique; TRUNCATE seat_allocation_bug;` | |
| 2 | A | `BEGIN ISOLATION LEVEL SERIALIZABLE;` | |
| 3 | A | `SELECT count(*) FROM seat_allocation_bug WHERE session_id = :sess AND seat_id = :seat;` | 0 |
| 4 | B | `BEGIN ISOLATION LEVEL SERIALIZABLE;` | |
| 5 | B | `SELECT count(*) FROM seat_allocation_bug WHERE session_id = :sess AND seat_id = :seat;` | 0 |
| 6 | A | `INSERT INTO seat_allocation_bug (session_id, seat_id, candidate_id) VALUES (:sess, :seat, :ca);` | INSERT 0 1 |
| 7 | B | `INSERT INTO seat_allocation_bug (session_id, seat_id, candidate_id) VALUES (:sess, :seat, :cb);` | INSERT 0 1 |
| 8 | A | `COMMIT;` | COMMIT |
| 9 | B | `COMMIT;` | **`ERROR: could not serialize access due to read/write dependencies among transactions`** (40001) |

### Part 5 — READ COMMITTED vs REPEATABLE READ

| Step | Terminal | Paste this | What you see |
|---|---|---|---|
| 1 | A | `BEGIN ISOLATION LEVEL READ COMMITTED;` | |
| 2 | A | `SELECT count(*) FROM seat_allocation WHERE session_id = :sess;` | 1 (Chiamaka) |
| 3 | B | `SELECT allocate_seat(:sess, :cb, :seat2, :fee);` | an allocation_id |
| 4 | A | `SELECT count(*) FROM seat_allocation WHERE session_id = :sess;` | **2** — changed inside one transaction |
| 5 | A | `COMMIT;` | |
| 6 | A | `BEGIN ISOLATION LEVEL REPEATABLE READ;` | |
| 7 | A | `SELECT count(*) FROM seat_allocation WHERE session_id = :sess;` | 2 |
| 8 | B | `SELECT allocate_seat(:sess, :cc, :seat3, :fee);` | an allocation_id (Grace) |
| 9 | A | `SELECT count(*) FROM seat_allocation WHERE session_id = :sess;` | **still 2** |
| 10 | A | `COMMIT;` then the same SELECT again | 3 |

### Part 6 — DEADLOCK (and the fix)

| Step | Terminal | Paste this | What you see |
|---|---|---|---|
| 1 | A | `BEGIN;` | |
| 2 | A | `SELECT seat_id FROM seat WHERE seat_id = :seat FOR UPDATE;` | locks seat 1 |
| 3 | B | `BEGIN;` | |
| 4 | B | `SELECT seat_id FROM seat WHERE seat_id = :seat2 FOR UPDATE;` | locks seat 2 |
| 5 | A | `SELECT seat_id FROM seat WHERE seat_id = :seat2 FOR UPDATE;` | **(waits…)** |
| 6 | B | `SELECT seat_id FROM seat WHERE seat_id = :seat FOR UPDATE;` | after ~1 s **`ERROR: deadlock detected`** (40P01) in one terminal |
| 7 | A and B | `ROLLBACK;` | |

**The fix:** both lock `WHERE seat_id IN (:seat, :seat2) ORDER BY seat_id FOR UPDATE` — the second one just waits its turn; no deadlock.

When finished: `\q` in both terminals.

---

## Why TestPoint uses FIX 2 (plus the unique constraint)

`allocate_seat()` uses Fix 2 for a clear message to the candidate, and the
`UNIQUE (seat_id, session_id)` constraint from Portfolio 1 stays as the safety
net for any code that bypasses the function. Moving a candidate between two
seats locks both seats in `seat_id` order (Part 6), so it can never deadlock.

> **Honesty reminder:** submit the output you get yourself
> (`race_demos_output.log` or screenshots of your two terminals) — not the
> "What you see" column above.
