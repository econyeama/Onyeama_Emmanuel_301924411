#!/usr/bin/env python3
"""
Portfolio 1 — bulk_data/generate_bulk.py
TestPoint CBT — bulk data generator.

Produces a realistic 2-year dataset:
    * ~12,000 candidates   (realistic Nigerian names, emails, phones)
    * ~1,100 sessions      (2 years back from today + 90 days forward)
    * ~55,000 seat allocations
          - each seat used at most once per session        (UNIQUE seat+session)
          - each candidate in at most one seat per session (UNIQUE cand+session)
          - no candidate in two overlapping sessions        (EXCLUDE tstzrange)
          - session allocation count <= centre capacity      (trigger)
    * matching registrations, payments (amount > 0), results (score 0–100)

Connection: Unix socket only (Codespaces rule). Peer auth as user 'postgres'.
    psycopg2.connect(dbname='testpoint', user='postgres',
                     host='/var/run/postgresql')

Run AFTER schema/*.sql has been applied. This script TRUNCATES the
transactional tables (candidate, exam_session, registration,
seat_allocation, payment, result) and repopulates them. centre / exam / seat
from 05_seed.sql are kept intact.

Usage:
    python3 portfolio-1-database-design/bulk_data/generate_bulk.py

Override the random seed for reproducible EXPLAIN plans in Portfolio 2:
    BULK_SEED=20260901 python3 .../generate_bulk.py
"""

import getpass
import os
import random
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import psycopg2
from psycopg2.extras import DateTimeTZRange, execute_values

# ---------------------------------------------------------------------------
# Determinism — fixed seed so two runs produce identical data (useful for
# reproducible EXPLAIN plans in Portfolio 2). Override with BULK_SEED env var.
# ---------------------------------------------------------------------------
SEED = int(os.environ.get("BULK_SEED", "20260901"))
random.seed(SEED)

DB = os.environ.get("TP_DB", "testpoint")
# Peer authentication: a Linux user may only log in as the database role with
# the same name, so connect as YOUR user (setup.sh creates that role).
PG_USER = os.environ.get("PGUSER") or getpass.getuser()
LAGOS = ZoneInfo("Africa/Lagos")
NOW = datetime.now(timezone.utc)
PG_HOST = os.environ.get("PGHOST", "/var/run/postgresql")  # Unix socket

# ---------------------------------------------------------------------------
# Realistic Nigerian name pools (Yoruba / Igbo / Hausa + general).
# ---------------------------------------------------------------------------
FIRST_MALE = [
    "Chidi", "Emeka", "Tunde", "Ibrahim", "Adewale", "Nnamdi", "Musa", "Sani",
    "Obi", "Uche", "Bode", "Seyi", "Kunle", "Danjuma", "Olumide", "Kelechi",
    "Yakubu", "Femi", "Chukwuemeka", "Abubakar", "Dele", "Tope", "Chuka",
    "Abdullahi", "Gbenga", "Obinna", "Tajudeen", "Bayo", "Emmanuel", "Yusuf",
]
FIRST_FEMALE = [
    "Aisha", "Ngozi", "Bola", "Fatima", "Yetunde", "Folake", "Chioma", "Hauwa",
    "Zainab", "Titilayo", "Ifeoma", "Adaora", "Halima", "Funke", "Amara",
    "Aminat", "Bisi", "Nneka", "Khadijah", "Oluwaseun", "Adaeze", "Maryam",
    "Sade", "Chinwe", "Rukayat", "Tolu", "Ebere", "Latifat", "Blessing", "Zainab",
]
LAST_NAMES = [
    "Okonkwo", "Bello", "Adeyemi", "Eze", "Mohammed", "Oluwole", "Nwosu",
    "Yusuf", "Okafor", "Abubakar", "Adebayo", "Ibrahim", "Obi", "Sani",
    "Adeola", "Diallo", "Ojo", "Aliyu", "Okeke", "Eze", "Adewale", "Musa",
    "Nnamdi", "Tijjani", "Ajayi", "Uche", "Bashir", "Chukwu", "Adeleke",
    "Onuoha", "Suleiman", "Olatunji", "Nwankwo", "Lawal", "Ezewele",
]
STATES = [
    "Lagos", "Oyo", "Anambra", "Kano", "Kaduna", "Enugu", "Imo", "Ogun",
    "Rivers", "FCT", "Edo", "Delta", "Kwara", "Osun", "Plateau", "Borno",
    "Sokoto", "Cross River", "Akwa Ibom", "Nasarawa",
]

# Session start hours within a day.
SLOT_HOURS = [9, 13, 16]


def gen_candidate(n):
    gender = random.choice(["M", "F"])
    first = random.choice(FIRST_MALE if gender == "M" else FIRST_FEMALE)
    last = random.choice(LAST_NAMES)
    email = f"{first.lower()}.{last.lower()}{n}@example.com"
    phone = f"+23480{random.randint(10000000, 99999999)}"
    state = random.choice(STATES)
    return first, last, email, phone, gender, state


def ranges_overlap(a_start, a_end, b_start, b_end):
    return a_start < b_end and b_start < a_end


def main():
    print(f"[bulk] connecting to PostgreSQL db={DB} user={PG_USER} host={PG_HOST}")
    conn = psycopg2.connect(dbname=DB, user=PG_USER, host=PG_HOST)
    conn.autocommit = False
    cur = conn.cursor()

    print("[bulk] truncating transactional tables …")
    cur.execute("""
        TRUNCATE TABLE result, payment, seat_allocation,
                     registration, candidate, exam_session
        RESTART IDENTITY CASCADE;
    """)

    # -------------------------------------------------------------------
    # 1. Read centres / exams / seats (kept from 05_seed.sql).
    # -------------------------------------------------------------------
    cur.execute("SELECT centre_id, seat_capacity FROM centre ORDER BY centre_id;")
    centres = cur.fetchall()
    cur.execute("SELECT exam_id, duration_minutes, default_fee FROM exam ORDER BY exam_id;")
    exams = cur.fetchall()
    cur.execute("""SELECT seat_id, centre_id FROM seat WHERE status='active'
                   ORDER BY centre_id, seat_id;""")
    seats_by_centre = {}
    for sid, cid in cur.fetchall():
        seats_by_centre.setdefault(cid, []).append(sid)

    # -------------------------------------------------------------------
    # 2. 12,000 candidates.
    # -------------------------------------------------------------------
    N_CANDIDATES = 12000
    print(f"[bulk] generating {N_CANDIDATES} candidates …")
    cand_rows = []
    seen_emails, seen_phones = set(), set()
    i = 0
    while i < N_CANDIDATES:
        first, last, email, phone, gender, state = gen_candidate(i + 1)
        if email in seen_emails or phone in seen_phones:
            continue
        seen_emails.add(email); seen_phones.add(phone)
        cand_rows.append((first, last, email, phone, gender, state))
        i += 1

    # Bulk insert candidates and read back the generated candidate_ids in order.
    cand_ids = execute_values(cur, """
        INSERT INTO candidate (first_name, last_name, email, phone, gender, state_of_origin)
        VALUES %s RETURNING candidate_id;
    """, cand_rows, page_size=1000, fetch=True)
    candidate_ids = [r[0] for r in cand_ids]
    print(f"[bulk]   inserted {len(candidate_ids)} candidates")

    # -------------------------------------------------------------------
    # 3. Sessions over a 2-year window ending 90 days from today.
    #    For each centre: 2 days per week (Tue + Sat) × up to 3 slots.
    # -------------------------------------------------------------------
    today = date.today()
    start_day = today - timedelta(days=730)
    end_day = today + timedelta(days=90)
    days = (end_day - start_day).days

    session_rows = []
    sess_meta = []  # (centre_id, capacity, fee, exam_id, start_dt, end_dt)
    for d_idx in range(days):
        d = start_day + timedelta(days=d_idx)
        if d.weekday() not in (1, 5):  # Tue=1, Sat=5
            continue
        for centre_id, capacity in centres:
            for slot in SLOT_HOURS:
                if random.random() > 0.6:  # ~60 % of slots used
                    continue
                exam_id, dur, fee = random.choice(exams)
                start_dt = datetime(d.year, d.month, d.day, slot, 0, tzinfo=LAGOS)
                end_dt = start_dt + timedelta(minutes=dur)
                status = "completed" if end_dt < NOW else "scheduled"
                session_rows.append((centre_id, exam_id, d, start_dt, end_dt,
                                     DateTimeTZRange(start_dt, end_dt, '[)'), fee, status))
                sess_meta.append((centre_id, capacity, fee, exam_id, start_dt, end_dt))

    sess_ids_rows = execute_values(cur, """
        INSERT INTO exam_session
            (centre_id, exam_id, session_date, start_time, end_time,
             session_range, fee, status)
        VALUES %s RETURNING session_id;
    """, session_rows, page_size=500, fetch=True)
    session_ids = [r[0] for r in sess_ids_rows]
    print(f"[bulk]   inserted {len(session_ids)} sessions "
          f"({start_day} → {end_day})")

    # session_id → (centre_id, capacity, fee, exam_id, start_dt, end_dt)
    session_lookup = list(zip(session_ids, sess_meta))

    # -------------------------------------------------------------------
    # 4. Allocations.
    #    For each session pick 40–90 % of the centre's active seats and assign
    #    a unique candidate not already booked in an overlapping session.
    # -------------------------------------------------------------------
    print("[bulk] planning allocations (enforcing EXCLUDE client-side) …")
    candidate_busy = {cid: [] for cid in candidate_ids}

    alloc_plan = []  # dicts
    reg_status_pool = ["allocated", "attended", "attended", "attended",
                       "attended", "attended", "attended", "no_show"]
    for sess_id, (centre_id, capacity, fee, exam_id, start_dt, end_dt) in session_lookup:
        centre_seats = seats_by_centre.get(centre_id, [])
        if not centre_seats:
            continue
        past = end_dt < NOW
        if past:
            lo, hi = int(capacity * 0.40), int(capacity * 0.90)
        else:
            # upcoming sessions: the further away, the emptier (free seats for P2/P3)
            days_ahead = (start_dt - NOW).days
            hi = int(capacity * max(0.15, 0.70 - 0.007 * days_ahead))
            lo = int(hi * 0.5)
        n_alloc = random.randint(lo, min(hi, len(centre_seats)))
        random.shuffle(centre_seats)
        for seat_id in centre_seats[:n_alloc]:
            cand = None
            for _ in range(40):
                c = random.choice(candidate_ids)
                busy = candidate_busy[c]
                if not any(ranges_overlap(start_dt, end_dt, bs, be)
                           for (bs, be) in busy):
                    cand = c
                    break
            if cand is None:
                continue
            candidate_busy[cand].append((start_dt, end_dt))
            # only past sessions can be attended / no-show; upcoming ones are just allocated
            reg_status = random.choice(reg_status_pool[1:]) if past else "allocated"
            registered_at = start_dt - timedelta(days=random.randint(3, 45), minutes=random.randint(0, 1440))
            if registered_at > NOW:
                registered_at = NOW - timedelta(minutes=random.randint(5, 600))
            alloc_plan.append({
                "session_id": sess_id,
                "seat_id": seat_id,
                "candidate_id": cand,
                "exam_id": exam_id,
                "fee": fee,
                "start_dt": start_dt,
                "end_dt": end_dt,
                "reg_status": reg_status,
                "registered_at": registered_at,
                "attended": reg_status == "attended",
                "checked_in": reg_status == "attended",
            })

    print(f"[bulk]   planned {len(alloc_plan):,} allocations")

    # ---- Registrations --------------------------------------------------
    print("[bulk] inserting registrations …")
    reg_input = [(a["candidate_id"], a["exam_id"], a["reg_status"], a["registered_at"]) for a in alloc_plan]
    reg_returned = execute_values(cur, """
        INSERT INTO registration (candidate_id, exam_id, status, registered_at)
        VALUES %s RETURNING registration_id;
    """, reg_input, page_size=2000, fetch=True)
    reg_ids = [r[0] for r in reg_returned]
    for a, rid in zip(alloc_plan, reg_ids):
        a["registration_id"] = rid
    print(f"[bulk]   inserted {len(reg_ids):,} registrations")

    # ---- Seat allocations ----------------------------------------------
    print("[bulk] inserting seat_allocations …")
    alloc_input = [(
        a["session_id"], a["seat_id"], a["candidate_id"], a["registration_id"],
        DateTimeTZRange(a["start_dt"], a["end_dt"], '[)'),
        a["checked_in"], a["attended"], a["registered_at"] + timedelta(minutes=random.randint(10, 120)),
    ) for a in alloc_plan]
    alloc_returned = execute_values(cur, """
        INSERT INTO seat_allocation
            (session_id, seat_id, candidate_id, registration_id,
             session_range, checked_in, attended, allocated_at)
        VALUES %s RETURNING allocation_id;
    """, alloc_input, page_size=2000, fetch=True)
    alloc_ids = [r[0] for r in alloc_returned]
    for a, aid in zip(alloc_plan, alloc_ids):
        a["allocation_id"] = aid
    print(f"[bulk]   inserted {len(alloc_ids):,} seat allocations")

    # ---- Payments: every allocated seat is paid. ~10 % of candidates had a
    #      FAILED first attempt (card declined) and paid successfully on retry.
    print("[bulk] inserting payments …")
    pay_input = []
    for a in alloc_plan:
        paid_at = a["registered_at"] + timedelta(minutes=random.randint(1, 60))
        if random.random() < 0.10:
            pay_input.append((a["registration_id"], a["fee"], "failed",
                              f"PAY-{a['registration_id']:07d}-F", paid_at - timedelta(minutes=3)))
        pay_input.append((a["registration_id"], a["fee"], "success",
                          f"PAY-{a['registration_id']:07d}-S", paid_at))
    execute_values(cur, """
        INSERT INTO payment (registration_id, amount, status, reference, paid_at)
        VALUES %s;
    """, pay_input, page_size=2000)
    print(f"[bulk]   inserted {len(pay_input):,} payments")

    # ---- Results (only for attended allocations; score 0–100) ----------
    print("[bulk] inserting results …")
    res_input = []
    for a in alloc_plan:
        if not a["attended"]:
            continue
        score = round(random.triangular(35, 95, 65), 2)
        graded = a["end_dt"] + timedelta(hours=random.randint(1, 72))
        res_input.append((a["allocation_id"], a["candidate_id"], a["exam_id"], score, min(graded, NOW)))
    execute_values(cur, """
        INSERT INTO result (allocation_id, candidate_id, exam_id, score, graded_at)
        VALUES %s;
    """, res_input, page_size=2000)
    print(f"[bulk]   inserted {len(res_input):,} results")

    conn.commit()

    # -------------------------------------------------------------------
    # 5. Verification counts — screenshot this for evidence.
    # -------------------------------------------------------------------
    cur.execute("""
        SELECT
          (SELECT count(*) FROM candidate)       AS candidates,
          (SELECT count(*) FROM exam_session)    AS sessions,
          (SELECT count(*) FROM seat_allocation) AS allocations,
          (SELECT count(*) FROM payment)         AS payments,
          (SELECT count(*) FROM result)          AS results,
          (SELECT min(session_date) FROM exam_session) AS first_day,
          (SELECT max(session_date) FROM exam_session) AS last_day,
          (SELECT count(*) FROM exam_session WHERE start_time > now()) AS upcoming;
    """)
    cands, sess, allocs, pays, ress, first_day, last_day, upcoming = cur.fetchone()
    print("")
    print("==============================================================")
    print(" BULK DATA SUMMARY — TestPoint CBT")
    print("==============================================================")
    print(f" candidates       : {cands:>8,}")
    print(f" sessions         : {sess:>8,}")
    print(f" seat allocations : {allocs:>8,}   (CA target: ≥ 50,000)")
    print(f" payments         : {pays:>8,}")
    print(f" results          : {ress:>8,}")
    print(f" session date span: {first_day}  →  {last_day}")
    print(f" upcoming sessions: {upcoming:>8,}   (partly booked, free seats left)")
    print("==============================================================")
    print("[bulk] DONE. Screenshot this terminal output for your evidence.")

    cur.close(); conn.close()


if __name__ == "__main__":
    main()
