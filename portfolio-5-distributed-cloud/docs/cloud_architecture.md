# Portfolio 5 — Cloud database architecture for TestPoint CBT

**Portfolio:** 5 · **Regulatory anchor:** Nigeria Data Protection Act 2023
(NDPA 2023).

This document describes the production-grade cloud architecture TestPoint
CBT would deploy to serve exam-day traffic across Lagos, Abuja, Ibadan,
Enugu and Kano **while keeping all candidate personal data inside Nigeria**,
as required by the NDPA 2023.

---

## 1. Why data residency matters — NDPA 2023

The **Nigeria Data Protection Act 2023** (the Act that established the
Nigeria Data Protection Commission, NDPC) requires that personal data of
Nigerians be:

- processed lawfully, fairly and transparently;
- collected for specified, explicit purposes;
- **stored in a manner that ensures security, integrity and
  confidentiality**, including protection against unauthorised access;
- **not transferred to a foreign country without an adequacy decision by
  the Commission** or appropriate safeguards (Part VIII — cross-border data
  transfer).

For TestPoint CBT, the personal data includes candidate names, phone
numbers, email addresses, state of origin, biometric check-in records, exam
scores and payment references. **All of this is in scope of the NDPA 2023.**
The architecture below keeps it inside Nigeria by using data centres
physically located in Lagos and Abuja (Nigerian colocation or local cloud
providers), and never replicates personal data outside Nigeria.

---

## 2. Reference cloud architecture

```
                          ┌────────────────────────────────────┐
                          │   TestPoint CBT — Cloud (Nigeria)  │
                          └────────────────────────────────────┘

  ┌──────────┐         ┌──────────────────────┐         ┌──────────────────────┐
  │ Candidate │  HTTPS  │   API + App tier     │   SQL   │   Database tier       │
  │ browser   │────────▶│  (Kubernetes, Lagos) │────────▶│  (Lagos + Abuja, AZs) │
  │  / phone  │         │  auto-scales on       │         │                       │
  └──────────┘         │  exam-day traffic     │         │  ┌────────────────┐   │
                       └──────────┬───────────┘         │  │ PRIMARY (RW)   │   │
                                  │                     │  │  port 5432     │   │
                                  │ MongoDB              │  │  Lagos AZ-A    │   │
                                  │ question bank        │  └───────┬───────┘   │
                                  ▼                     │          │ streaming │
                          ┌──────────────────┐          │  ┌───────▼───────┐   │
                          │  Read replicas    │          │  │ REPLICA (RO)  │   │
                          │  for reporting    │◀─────────│  │  port 5433    │   │
                          │  + analytics      │  async   │  │  Lagos AZ-B   │   │
                          └──────────────────┘  replay   │  └───────────────┘   │
                                                            └──────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────┐
  │ Cross-AZ DR: a SECOND replica streams to Abuja AZ-A (warm standby).  │
  │ Lagos → Abuja replication is ASYNC (see CAP writeup for trade-offs). │
  └──────────────────────────────────────────────────────────────────────┘
```

### Components

| Component | Technology | Why |
|---|---|---|
| App tier | Kubernetes (self-managed, in a Lagos data centre) | Auto-scales invigilator check-in and candidate booking pods on exam-day peaks |
| Primary DB | PostgreSQL 16 in a Lagos availability zone | Single writer; enforces all P1 constraints + P3 transactions |
| Read replica 1 (Lagos, other AZ) | PostgreSQL 16 streaming replica (this Portfolio 5 demo) | Reporting / Portfolio 2 queries; protects the primary from heavy reads |
| Read replica 2 (Abuja) | PostgreSQL 16 streaming replica, ASYNC | Disaster-recovery warm standby; data stays in Nigeria |
| Question bank | MongoDB 8 replica set (3 nodes, Lagos primary + 2 Lagos secondaries) | Heterogeneous document store for the question bank (Portfolio 4) |
| Object storage | S3-compatible (e.g. AWS Africa Cape Town is OUTSIDE Nigeria — we use a Lagos-region equivalent or self-hosted MinIO) | Exam diagrams, question images, signed check-in photos |
| Backups | pgBackRest to encrypted Lagos object storage, PITR every 5 min | NDPA 2023 — security and integrity of personal data |
| Monitoring | Prometheus + Grafana, Lagos | Lag, capacity, utilisation alerts |
| Secrets | HashiCorp Vault (Lagos) or cloud KMS in a Nigerian region | Payment gateway keys, DB passwords |
| Edge / CDN | A Nigerian-presence CDN (e.g.自己 a caching reverse proxy in Lagos) | Question images, static exam UI assets |

---

## 3. Keeping data in Nigeria — concrete rules

1. **Primary region = Lagos (or Abuja).** Every database, object store and
   backup target lives in an availability zone physically inside Nigeria.
2. **DR region = Abuja.** The cross-region replica is async, but it is
   inside Nigeria — the NDPA cross-border transfer rules (Part VIII) never come into play.
3. **CDN allow-list.** Any CDN node that serves candidate data must have a
   PoP in Nigeria; foreign PoPs only cache non-personal static assets.
4. **Backup copies.** All `pgBackRest` backups are pinned to a Lagos object
   storage bucket with region-lock; no copy is sent abroad.
5. **Logging.** Application logs that contain candidate PII (e.g. check-in
   events with name + email) are shipped only to a Lagos log store; the
   generic non-PII telemetry may go to a foreign observability SaaS.
6. **No foreign SaaS for PII.** Payment processing uses a Nigerian PSP
   (Paystack / Flutterwave) whose data residency is documented as in-country.
7. **NDPA register.** TestPoint maintains the NDPC-required Record of
   Processing Activities and appoints a Data Protection Officer.

---

## 4. Exam-day traffic peaks — how the architecture absorbs them

TestPoint's load is spiky: a recruitment exam (e.g. NNPC) can flood the
system with tens of thousands of candidates all starting within the same
9:00 slot on a Saturday. The architecture handles this through:

| Layer | Peak-handling mechanism |
|---|---|
| App tier | Kubernetes HPA scales booking + check-in pods from, say, 4 → 60 in < 60 s based on CPU + custom queue-depth metric. |
| Database writes | The **primary** is the only writer; seat allocation uses `SELECT … FOR UPDATE` (Portfolio 3 Fix 2) so contended writes serialise cleanly rather than deadlocking. |
| Database reads | All Portfolio 2 reporting queries run against **read replicas** ( Lagos AZ-B and Abuja), so the primary's CPU is reserved for writes. |
| Connection pooling | PgBouncer in front of the primary (transaction-mode, ~100 server connections per pod) so 60 pods × 50 client conns = 3000 client conns map to ≤ 200 server conns. |
| Question bank | MongoDB replica set; reads go to secondaries; the primary only ingests new questions from the editorial back-office. |
| Caching | Redis (Lagos) caches the "free seats per session" result for ~5 s — long enough to absorb a burst of identical "show me free seats" requests, short enough to stay fresh. |
| Queue | Booking confirmations and payment callbacks go through a Lagos message queue (e.g. self-hosted NATS) so a PSP outage does not block the candidate's seat. |
| Read-replica lag budget | Lagos-AZ-B replica is **synchronous** (`synchronous_commit = on`, `synchronous_standby_names`) for the few queries that must read-their-own-write (e.g. invigilator check-in); the Abuja DR replica is async. |
| Back-pressure | If lag exceeds 5 s, the app tier returns HTTP 503 for reporting queries and falls back to "results pending" — never silently shows stale data. |

---

## 5. Partitioning (this portfolio, sql/01_partitioning.sql)

`seat_allocation_part` is range-partitioned by month into 24 monthly
partitions. Reporting queries filtered by month (the common case for
"revenue this month") hit only one partition thanks to **partition
pruning**, cutting I/O by ~24×.

For a multi-region deployment the partitioning strategy extends naturally:

- **By month** (this demo) — good for time-windowed reporting.
- **By centre region** (Lagos / Abuja / North) — enables region-local
  partitions that can be pinned to a local storage tier; useful if Kano
  grows much faster than the others.
- **By hash(candidate_id)** — sharding for write throughput if a single
  primary cannot keep up.

---

## 6. Streaming replication (this portfolio, sql/02_replica_setup.sh)

This Codespaces demo runs the primary on port 5432 and a streaming replica
on port 5433 inside the same codespace, but the same setup scripts apply to
real Lagos/Abuja hosts:

| Step in `02_replica_setup.sh` | Real-world analogue |
|---|---|
| `wal_level = replica`, `max_wal_senders = 10` on the primary | Same configuration on the Lagos primary |
| `pg_hba.conf` trust lines for the `repl` role | Same, but with `scram-sha-256` instead of `trust` and TLS |
| `pg_basebackup -R -S replica1` | Take the initial base backup from the Lagos primary into the Abuja host |
| `port = 5433`, `hot_standby = on` on the replica | The Abuja host runs on 5432 locally; `hot_standby = on` lets it serve read-only queries |
| `sql/03_replica_tests.sql` shows the replica rejecting writes and receiving new rows | Same verification on the real Abuja host |

---

## 7. Summary — does the architecture meet NDPA 2023?

| NDPA 2023 principle | How the architecture meets it |
|---|---|
| Lawful, fair, transparent processing | Candidates consent at registration; privacy policy stored in the Lagos app tier |
| Purpose limitation | Each table has a documented purpose in `docs/case_study.md` |
| Data minimisation | The schema stores only what is needed for booking, payment, scoring, audit |
| Security, integrity, confidentiality | TLS in transit, encryption at rest, RBAC, PgBouncer, Vault-managed secrets, Lagos-only backups |
| Cross-border transfer rules | All personal data stays in Nigeria (Lagos + Abuja); no foreign replication, so no cross-border transfer assessment is needed |
| Data subject rights | A `candidate` row can be exported / corrected / deleted via the app tier; the schema supports it directly |
| Storage limitation (retention) | `seat_allocation_part` partitioning lets us detach + archive old monthly partitions to cold Lagos storage and eventually purge them on schedule |

The architecture is therefore both **operationally fit for exam-day
peaks** and **NDPA 2023 compliant**.
