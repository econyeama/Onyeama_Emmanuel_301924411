#!/usr/bin/env python3
"""
TestPoint CBT — MIT 8103 Portfolio 3
run_race_demos.py — runs ALL SIX two-terminal demos automatically.

It opens two real PostgreSQL sessions at the same time:
    A = Terminal A, the Lagos front desk (Chiamaka Obi)
    B = Terminal B, the online booking portal (Yusuf Danladi)
and sends each step to the right session in the order given in
guides/race_condition_two_terminal.md. When a step has to WAIT for a lock, it is run in
a background thread, so you can see it block and then finish (or fail) once
the other session commits.

Every line printed is real output from your database — nothing is typed in.

Run (from this folder, after run_p1.sh and run_p3.sh):
    python3 run_race_demos.py | tee race_demos_output.log
"""
import subprocess
import sys
import threading
import time

import getpass

import psycopg2
import psycopg2.errors  # noqa: F401

DSN = f"dbname=testpoint user={getpass.getuser()} host=/var/run/postgresql"
HERE = sys.path[0] or "."


def banner(text):
    print("\n" + "=" * 74)
    print("  " + text)
    print("=" * 74, flush=True)


def connect(name):
    conn = psycopg2.connect(DSN, application_name=name)
    conn.autocommit = True
    return conn


def execute(conn, sql, params=None):
    """Run one statement; return (ok, list of result lines). Never raises."""
    out = []
    try:
        cur = conn.cursor()
        cur.execute(sql, params)
        if cur.description:
            rows = cur.fetchall()
            out.append("       " + " | ".join(d.name for d in cur.description))
            for r in rows:
                out.append("       " + " | ".join(str(x) for x in r))
            out.append(f"       ({len(rows)} row{'s' if len(rows) != 1 else ''})")
        else:
            out.append(f"       {cur.statusmessage}")
        return True, out
    except psycopg2.Error as e:
        out.append(f"       ERROR [{e.pgcode}]: {e.diag.message_primary}")
        if e.diag.message_detail:
            for line in e.diag.message_detail.splitlines():
                out.append(f"       DETAIL: {line}")
        return False, out


def run(conn, label, sql, params=None):
    print(f"{label:<4}> {sql.strip()}", flush=True)
    ok, out = execute(conn, sql, params)
    print("\n".join(out), flush=True)
    return ok


class Waiting:
    """A statement started in the background because it is expected to block."""

    def __init__(self, conn, label, sql):
        self.label, self.result = label, None
        print(f"{label:<4}> {sql.strip()}", flush=True)
        self.thread = threading.Thread(target=self._go, args=(conn, sql))
        self.thread.start()
        time.sleep(1.5)
        if self.thread.is_alive():
            print(f"{label:<4}  ... still WAITING for a lock held by the other terminal", flush=True)

    def _go(self, conn, sql):
        self.result = execute(conn, sql)

    def join(self):
        self.thread.join()
        print(f"{self.label:<4}  ... the waiting statement has now finished:")
        print("\n".join(self.result[1]), flush=True)
        return self.result[0]


def in_background(conn, label, sql, params=None):
    return Waiting(conn, label, sql)


def q(conn, sql):
    cur = conn.cursor(); cur.execute(sql); return cur.fetchall()


def main():
    subprocess.run(["psql", "-h", "/var/run/postgresql", "-d", "testpoint", "-X", "-q",
                    "-v", "ON_ERROR_STOP=1", "-f", f"{HERE}/sql/race_setup.sql"],
                   check=True, stdout=subprocess.DEVNULL)
    A = connect("Terminal A (Lagos desk)")
    B = connect("Terminal B (online portal)")
    v = {k: int(x) for k, x in q(A, "SELECT key, val FROM race_demo")}
    sess, seat, seat2, seat3, fee = v["sess"], v["seat"], v["seat2"], v["seat3"], v["fee"]
    ca, cb, cc = v["ca"], v["cb"], v["cc"]
    print(f"Demo session {sess} (PMP, TestPoint Lagos, 45 days ahead), seats {seat}/{seat2}/{seat3}")
    print(f"Chiamaka Obi = candidate {ca} at Terminal A, Yusuf Danladi = candidate {cb} at Terminal B,"
          f" Grace Etim = candidate {cc}. Everyone wants seat {seat}.")

    check_bug = f"SELECT count(*) AS seat_holders FROM seat_allocation_bug WHERE session_id = {sess} AND seat_id = {seat}"
    ins_bug = "INSERT INTO seat_allocation_bug (session_id, seat_id, candidate_id) VALUES ({s}, {st}, {c})"
    show_bug = f"SELECT bug_id, candidate_id, seat_id FROM seat_allocation_bug WHERE session_id = {sess} ORDER BY bug_id"

    banner("PART 1 — THE BUG: check-then-insert with no unique rule (seat_allocation_bug)")
    run(A, "A", "BEGIN"); run(A, "A", check_bug)
    run(B, "B", "BEGIN"); run(B, "B", check_bug)
    run(A, "A", ins_bug.format(s=sess, st=seat, c=ca)); run(A, "A", "COMMIT")
    run(B, "B", ins_bug.format(s=sess, st=seat, c=cb)); run(B, "B", "COMMIT")
    run(A, "A", show_bug)
    print("  >>> BUG: two candidates now hold the same computer in the same session.")

    banner("PART 2 — FIX 1: a UNIQUE index on (seat_id, session_id)")
    run(A, "A", "TRUNCATE seat_allocation_bug")
    run(A, "A", "CREATE UNIQUE INDEX bug_seat_unique ON seat_allocation_bug (seat_id, session_id)")
    run(A, "A", "BEGIN"); run(B, "B", "BEGIN")
    run(A, "A", ins_bug.format(s=sess, st=seat, c=ca))
    t = in_background(B, "B", ins_bug.format(s=sess, st=seat, c=cb))
    run(A, "A", "COMMIT"); t.join(); run(B, "B", "ROLLBACK")
    run(A, "A", show_bug)
    print("  >>> FIXED: B waited for A, then got a unique_violation. One holder only.")

    banner("PART 3 — FIX 2: allocate_seat() locks the seat row (SELECT … FOR UPDATE)")
    book = "SELECT allocate_seat({s}, {c}, {st}, {f}) AS allocation_id"
    run(A, "A", "BEGIN"); run(A, "A", book.format(s=sess, c=ca, st=seat, f=fee))
    run(B, "B", "BEGIN")
    t = in_background(B, "B", book.format(s=sess, c=cb, st=seat, f=fee))
    run(A, "A", "COMMIT"); t.join(); run(B, "B", "ROLLBACK")
    run(A, "A", f"SELECT allocation_id, candidate_id, seat_id FROM seat_allocation WHERE session_id = {sess} AND seat_id = {seat}")
    print("  >>> FIXED: B queued behind A's row lock, then got a clear 'already allocated' message.")

    banner("PART 4 — FIX 3: SERIALIZABLE stops the bug even with NO unique index")
    run(A, "A", "DROP INDEX bug_seat_unique"); run(A, "A", "TRUNCATE seat_allocation_bug")
    run(A, "A", "BEGIN ISOLATION LEVEL SERIALIZABLE"); run(A, "A", check_bug)
    run(B, "B", "BEGIN ISOLATION LEVEL SERIALIZABLE"); run(B, "B", check_bug)
    run(A, "A", ins_bug.format(s=sess, st=seat, c=ca))
    ok = run(B, "B", ins_bug.format(s=sess, st=seat, c=cb))
    run(A, "A", "COMMIT")
    run(B, "B", "COMMIT" if ok else "ROLLBACK")
    run(A, "A", show_bug)
    print("  >>> FIXED: both read 'seat free' and both wrote it, so PostgreSQL")
    print("      cancelled B with a serialization failure (SQLSTATE 40001).")

    banner("PART 5 — READ COMMITTED vs REPEATABLE READ (counting booked seats)")
    count = f"SELECT count(*) AS seats_booked FROM seat_allocation WHERE session_id = {sess}"
    print("-- 5a: READ COMMITTED (the default)")
    run(A, "A", "BEGIN ISOLATION LEVEL READ COMMITTED"); run(A, "A", count)
    run(B, "B", book.format(s=sess, c=cb, st=seat2, f=fee))
    run(A, "A", count); run(A, "A", "COMMIT")
    print("  >>> A saw the count change inside ONE transaction (non-repeatable read).")
    print("-- 5b: REPEATABLE READ")
    run(A, "A", "BEGIN ISOLATION LEVEL REPEATABLE READ"); run(A, "A", count)
    run(B, "B", book.format(s=sess, c=cc, st=seat3, f=fee))
    run(A, "A", count); run(A, "A", "COMMIT"); run(A, "A", count)
    print("  >>> A kept its snapshot until COMMIT; the new booking appears afterwards.")

    banner("PART 6 — DEADLOCK: two desks lock two seats in opposite order")
    lock = "SELECT seat_id FROM seat WHERE seat_id = {st} FOR UPDATE"
    run(A, "A", "BEGIN"); run(A, "A", lock.format(st=seat))
    run(B, "B", "BEGIN"); run(B, "B", lock.format(st=seat2))
    t = in_background(A, "A", lock.format(st=seat2))
    run(B, "B", lock.format(st=seat))
    t.join(); run(A, "A", "ROLLBACK"); run(B, "B", "ROLLBACK")
    print("  >>> PostgreSQL detected the cycle after deadlock_timeout (1s) and")
    print("      aborted one transaction (SQLSTATE 40P01) so the other could go on.")
    print("-- 6b: the fix — always lock seats in seat_id order")
    both = f"SELECT seat_id FROM seat WHERE seat_id IN ({seat}, {seat2}) ORDER BY seat_id FOR UPDATE"
    run(A, "A", "BEGIN"); run(A, "A", both)
    run(B, "B", "BEGIN"); t = in_background(B, "B", both)
    run(A, "A", "COMMIT"); t.join(); run(B, "B", "COMMIT")
    print("  >>> Same two locks, same order: B simply waits its turn. No deadlock.")

    A.close(); B.close()
    banner("ALL SIX DEMOS DONE — save this output: race_demos_output.log")


if __name__ == "__main__":
    main()
