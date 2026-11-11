# Portfolio 5 — CAP theorem, sync vs async replication, exam-day trade-offs

**Portfolio:** 5 · **Study sessions covered:** Study Session 2
(*Distributed Database System*: CAP theorem, BASE vs ACID, consistency
models) + Study Session 3 (*Cloud Database Systems*).

This document explains the consistency / availability / partition-tolerance
trade-offs TestPoint CBT makes, with the sync-vs-async replication decision
made concrete using the streaming replica built in `sql/02_replica_setup.sh`.

---

## 1. The CAP theorem, in one paragraph

**CAP** (Brewer, 2000; formal proof by Gilbert & Lynch, 2002) says a
distributed data store can provide at most **two** of these three guarantees
during a network partition:

- **C**onsistency — every read sees the latest write or an error.
- **A**vailability — every request gets a non-error response (not
  necessarily the latest).
- **P**artition tolerance — the system keeps working when the network
  between nodes drops messages.

Because real networks **do** partition, P is non-negotiable. The real choice
is **CP** (sacrifice availability — refuse a write if you cannot reach a
quorum) vs **AP** (sacrifice consistency — accept the write on the
reachable node and reconcile later).

---

## 2. TestPoint's CAP choices, by subsystem

| Subsystem | CAP choice | Reasoning |
|---|---|---|
| Seat allocation (write path) | **CP** | Double-booking a seat is a hard business error. If the primary cannot reach a quorum, it refuses the write and the candidate is asked to retry. Availability loss is acceptable because the alternative is data corruption. |
| Payment capture | **CP** | Same — never accept a payment without confirming the allocation is durable. |
| Reporting / analytics queries (Portfolio 2) | **AP** | A read replica that is a few seconds behind is fine for "revenue per centre" dashboards. Eventual consistency is acceptable. |
| Question bank reads (Portfolio 4) | **AP** | The question bank is read-mostly; MongoDB replica set secondaries may lag a fraction of a second. Candidates see the same question they would have seen 1 s ago — fine. |
| Exam-day check-in (invigilator) | **CP** with sync standby | The check-in must be durable before the invigilator sees "checked in"; a synchronous standby in the same Lagos AZ gives RPO=0 with negligible latency. |

---

## 3. Sync vs async replication — the trade-off

PostgreSQL streaming replication can be:

- **Synchronous** — `synchronous_commit = on`, `synchronous_standby_names`
  names a standby that MUST acknowledge each commit before the client gets
  a COMMIT-ok. **Strong consistency**, but the write latency is at least
  one round-trip to the standby; if the standby dies, writes block.
- **Asynchronous** — the primary commits as soon as the local WAL is
  flushed; the standby replays later. **Low write latency**, but if the
  primary dies between a commit and the standby catching up, that
  transaction is lost (RPO > 0).

### What TestPoint uses where

| Path | Mode | Standby | RPO | Latency cost |
|---|---|---|---|---|
| Invigilator check-in | **SYNC** | Lagos AZ-B replica | 0 | +1–3 ms per write |
| Seat allocation + payment | **SYNC** | Lagos AZ-B replica | 0 | +1–3 ms per write |
| Reporting replica (Portfolio 2 reads) | **ASYNC** | Lagos AZ-B (also the sync standby for writes — read with a small lag budget) | seconds | 0 extra |
| DR replica (Abuja) | **ASYNC** | Abuja AZ-A | seconds–minutes | 0 extra |
| Question bank secondary | **ASYNC** | MongoDB secondary | milliseconds | 0 extra |

The reasoning: writes that lose data on failover (a checked-in candidate
whose record disappears) must be synchronous; reads and DR copies that can
tolerate a few seconds of staleness are asynchronous so latency stays low
and the primary never blocks.

---

## 4. CAP during a partition — concrete failure modes

### Failure 1 — the Lagos-AZ-B standby (the sync one) dies

- The primary still accepts writes from the app tier (PostgreSQL with
  `synchronous_standby_names = ANY 1 (...)` and at least one other sync
  candidate will block; if there is no other sync candidate, writes block
  until the standby returns or is demoted from sync list).
- Operationally, TestPoint runs **two** sync standbys (Lagos AZ-B +
  Lagos AZ-C) so a single standby outage does not block writes.
- Reporting queries that were hitting AZ-B are re-routed to AZ-C or to the
  async DR replica in Abuja (slightly staler, but available).

### Failure 2 — the network between Lagos and Abuja partitions

- The **Lagos primary keeps accepting writes** (the sync standbys are all
  in Lagos). Lagos stays CP and available.
- The **Abuja async DR replica stops receiving WAL**; it serves stale
  reads until the partition heals. It will NOT be promoted (no
  split-brain) because it is not in the promotion priority list.
- When the partition heals, the Abuja replica catches up automatically
  (PostgreSQL's WAL receiver reconnects and streams the backlog).

### Failure 3 — the Lagos primary dies

- The sync standby in Lagos AZ-B is promoted via Patroni (or `pg_ctl
  promote`). Because it was synchronous, it has every committed
  transaction — **RPO = 0**.
- The app tier's PgBouncer reconnects to the new primary within seconds.
- The Abuja async DR replica follows the new primary once Patroni
  re-establishes streaming.

### Failure 4 — split-brain scenario avoided

TestPoint uses **Patroni + etcd** (both in Lagos) for leader election. A
partitioned Abuja host cannot elect itself primary because etcd quorum is
in Lagos. This prevents the classic split-brain where two primaries accept
conflicting writes.

---

## 5. ACID vs BASE (Study Session 2)

| | ACID (SQL / PostgreSQL) | BASE (NoSQL / MongoDB at scale) |
|---|---|---|
| **A**tomicity / **B**asically available | Whole transaction or nothing | Single document atomic; multi-doc less so |
| **C**onsistency / **S**oft state | Strong (serialisable if needed) | Tunable; often "eventual" |
| **I**solation / **E**ventual consistency | MVCC snapshots | Replica lag = staleness window |
| **D**urability | WAL + sync standby | Write concern `w:majority` for durability |

TestPoint uses **ACID** (PostgreSQL) for the seat-allocation / payment
transactional core (P1, P2, P3) and **BASE-ish** (MongoDB with
`w:majority` for durability but `readConcern=local` for speed) for the
read-mostly question bank (P4). The split is the same one discussed in
`portfolio-4-nosql/docs/sql_vs_nosql.md`.

---

## 6. Exam-day traffic peaks — quantitative reasoning

Assume an NNPC recruitment exam: **80,000 candidates** sitting across 5
TestPoint centres simultaneously at 09:00 on a Saturday.

- **Write load at 09:00:** every candidate clicks "start exam" within ~60 s.
  That is ~1,300 check-ins/second. The primary can handle ~5,000
  inserts/s on the TestPoint hardware spec, so there is headroom.
- **Read load at 09:00:** the UI fetches each candidate's questions (from
  MongoDB secondaries — no SQL read needed) + their booking record (from a
  read replica). ~1,300 reads/s — trivial.
- **Reporting load:** centre managers refresh utilisation dashboards every
  30 s — a handful of queries per centre, served by read replicas.
- **Replication lag budget:** sync standby adds 1–3 ms per write. With
  ~1,300 writes/s, the lag stays under 1 s. The async DR replica lags by
  ~5–10 s under this load — acceptable for DR.
- **Partitioning benefit:** `seat_allocation_part` is partitioned by month.
  Exam-day writes all hit the current month's partition, so the write
  path's B-tree index stays small (~1/24 of the unpartitioned size) and
  fits in RAM.

If write load ever exceeds a single primary, the next step is **sharding
by `centre_id`**: each centre's allocations live on a different shard, and
a coordinator routes writes by `centre_id`. This is the natural
horizontal-scaling extension of the partitioning demonstrated in
`sql/01_partitioning.sql`.

---

## 7. Conclusion

TestPoint's distributed/cloud design is deliberately **hybrid**:

- **CP** for the seat-allocation write path (sync standby, RPO=0).
- **AP** for the read-mostly reporting and question-bank paths (async
  replicas, eventual consistency, low latency).
- **Inside Nigeria** for NDPA 2023 data residency (Lagos primary + Lagos
  sync standby + Abuja async DR).
- **Partitioned by month** so time-windowed reporting queries prune to a
  single partition.
- **Auto-scaling app tier + PgBouncer + Redis** for exam-day bursts.

This is the practical application of Study Session 2 (CAP, ACID/BASE,
consistency models) and Study Session 3 (cloud database systems) to the
TestPoint CBT business.
