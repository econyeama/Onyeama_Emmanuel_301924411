# MIT 8103 — Advanced Database Systems Portfolio

**Student:** Emmanuel Onyeama  
**Matric number:** 2026/A/MIT/0876  
**Programme:** Master of Information Technology, Miva Open University  
**Course:** MIT 8103 Advanced Database Systems (2026/2027, First Semester CA)  
**GitHub repository:** [GitHub link]

---

## 1. Selected case study

**TestPoint CBT** is a simulated Nigerian company that runs computer-based
test (CBT) centres across five cities — **Lagos, Abuja, Ibadan, Enugu and
Kano** — for professional certification exams (PMP, ACCA, ICAN, Cisco
CCNA, Microsoft AZ-900, AWS Cloud Practitioner, TOEFL, IELTS) and for
recruitment tests (NNPC, CBN, FIRS, Dragnet, SHL).

| Item | Detail |
|---|---|
| Business | Operating CBT examination centres across Nigeria |
| Users of the database | Candidates, invigilators, accounts/finance staff, centre managers, exam body auditors |
| Major data stored | Centres, exam definitions, scheduled sessions, seats (computers), candidates, registrations, seat allocations, payments, results |
| Key operations supported | Candidate registration, session/centre selection, automatic seat allocation, payment capture, exam-day check-in, result recording, utilisation & revenue reporting, exam-day scale-out |

The same case study is used **consistently across all five portfolios** as
required by section 2 of the CA brief.

---

## 2. Repository structure

```
advanced-database-portfolio/
├── README.md                      ← this file
├── setup.sh                       ← installs PostgreSQL 16 + MongoDB 8 in Codespaces
├── portfolio-1-database-design/
│   ├── run_p1.sh
│   ├── er_diagram.mmd
│   ├── schema/                    ← extensions, tables, constraints, triggers, seed
│   ├── bulk_data/generate_bulk.py ← 50k+ seat allocations over 2 years
│   ├── tests/constraint_tests.sql ← statements that MUST fail
│   └── docs/                      ← case study + 3NF notes
├── portfolio-2-query-optimisation/
│   ├── run_p2.sh
│   ├── queries/                   ← 6 core + 2 bonus queries
│   ├── indexes/create_indexes.sql
│   └── results/before_after_table.md
├── portfolio-3-transactions-concurrency/
│   ├── run_p3.sh
│   ├── sql/                       ← allocate_seat(), COMMIT/ROLLBACK, isolation, deadlock
│   └── guides/race_condition_two_terminal.md  ← two-terminal psql walkthrough
├── portfolio-4-nosql/
│   ├── run_p4.sh
│   ├── js/                        ← create, validate, seed, aggregate, index demo
│   ├── bulk_data/generate_questions.py  ← 40k+ documents
│   └── docs/sql_vs_nosql.md
└── portfolio-5-distributed-cloud/
    ├── run_p5.sh
    ├── sql/                       ← monthly partitioning + streaming replica
    └── docs/                      ← cloud architecture (NDPA 2023), CAP, traffic peaks
```

---

## 3. Quick start (GitHub Codespaces)

1. Create a new Codespace (Ubuntu 24.04 image, 4-core / 16 GB recommended).
2. Clone your private repo into the codespace and `cd` into it.
3. Run the bootstrap once:

   ```bash
   bash setup.sh
   ```

   This installs **PostgreSQL 16** + **MongoDB 8.0**, creates the `testpoint`
   role/database, enables `btree_gist`, and starts `mongod` bound to
   `127.0.0.1:27017`. Every Postgres connection in this repo uses the
   **Unix socket** (`/var/run/postgresql`) with peer auth, so no password is
   ever required.

4. Run each portfolio in order:

   ```bash
   bash portfolio-1-database-design/run_p1.sh   # schema + seed + 50k bulk data + constraint tests
   bash portfolio-2-query-optimisation/run_p2.sh # 9 queries + EXPLAIN ANALYZE before/after
   bash portfolio-3-transactions-concurrency/run_p3.sh
   bash portfolio-4-nosql/run_p4.sh
   bash portfolio-5-distributed-cloud/run_p5.sh
   ```

   The two-terminal race-condition walkthrough in
   `portfolio-3-transactions-concurrency/guides/race_condition_two_terminal.md`
   is **interactive** — open two psql terminals side-by-side and follow the
   steps. The streaming-replica part of Portfolio 5 is also interactive.

---

## 4. Codespaces-specific notes (read before running)

| Rule | What we do |
|---|---|
| `sudo -u postgres` is not available | Every script uses `sudo runuser -u postgres -- psql …` |
| PostgreSQL config location | `/etc/postgresql/16/main/`; `pg_ctl` at `/usr/lib/postgresql/16/bin/pg_ctl` |
| Replica needs own config | `pg_basebackup` then a standalone `postgresql.conf` under the replica data dir |
| `pg_hba.conf` trust lines | Always prepended at the **top** of the file (the default `local all postgres peer` block sits below and would otherwise shadow them) |
| TCP logins need a password | All `psql` calls pass `host=/var/run/postgresql` (Unix socket, peer auth) |
| `postgres_fdw` is forbidden | Not used anywhere — Portfolio 5 uses logical streaming replication only |
| `yarn.list` breaks `apt-get update` | Removed at the top of `setup.sh` before the first `apt-get update` |
| Dates must be relative to today | Every generator uses `CURRENT_DATE` / `now()` / Python `date.today()` with `timedelta`, never fixed past dates |

---

## 5. Honesty statement

This repository contains **only runnable code, schema and generators**. No
EXPLAIN plans, no timings, no screenshot contents, no result sets have been
invented. Anywhere a real captured result must go you will find the literal
placeholder

```
[paste real output here]
```

The 2–3 page documentation PDF (`Onyeama_Emmanuel_2026-A-MIT-0876_Documentation.pdf`)
will be produced **after** all five portfolios have actually been executed
in Codespaces, and will only contain real captured results, the real GitHub
link, and an honest AI-use declaration.

---

## 6. AI use declaration (summary; full version goes in the final PDF)

| Item | Detail |
|---|---|
| AI tool used | Z.ai (GLM) conversational assistant |
| What it was used for | (1) Generating the initial SQL schema, constraints, triggers, and Python/MongoDB generators; (2) Drafting the run scripts and READMEs; (3) Explaining the course-note study sessions and mapping them to portfolios |
| Testing and fixes | Claude (Anthropic) then ran every script in a Codespaces-like environment and fixed what failed — every fix is listed in `CHANGES.md` |
| How output was reviewed | The student ran all five portfolios in their own GitHub Codespace; every result in the documentation is real output from that run (`pN_output.log`, `race_demos_output.log`, `replication_output.log`, `my_results.txt`) |
| Responsibility | The student remains responsible for the accuracy, originality and understanding of everything submitted, and can explain the work if selected for verification |

---

## 7. Portfolio ↔ course-note study-session map

| Portfolio | Course-note study session(s) it demonstrates |
|---|---|
| 1 — Database Design and Modelling | **Study Session 1** (Review of Traditional Relational Databases: normalisation, database design stages, keys, constraints, characteristics of a good database) |
| 2 — Query Processing and Optimisation | **Study Session 4** (Query Optimisation: introduction to queries, query optimisation, query execution plans and cost estimation) |
| 3 — Transactions and Concurrency | **Study Session 1** (ACID within the traditional RDBMS) + **Study Session 2** (CAP/ACID/BASE trade-offs appear when discussing isolation and the distributed analogue) |
| 4 — NoSQL and Advanced Data Models | **Study Session 3** (Big Data and Cloud Database Systems) + **Study Session 5** (Emerging Trends: graph/document DBs and the NoSQL family) |
| 5 — Distributed and Cloud Database Exercise | **Study Session 2** (Distributed Database System: replication, fragmentation, CAP, consistency models) + **Study Session 3** (Cloud Database Systems) + **Study Session 6** (Data Privacy — NDPA 2023, keeping data in Nigeria) |

---

## 8. Progressive commit plan

The CA brief rewards **progressive GitHub commits**. Suggested commit order
(each tag is a real `git` milestone):

```bash
git init && git add README.md setup.sh && git commit -m "chore: repo bootstrap + setup.sh (PG16/Mongo8)"
git tag p0-bootstrap

bash portfolio-1-database-design/run_p1.sh   # then commit
git add portfolio-1-database-design/ && git commit -m "feat(p1): schema, 3NF, 50k bulk data, constraint tests"
git tag p1-design

# … repeat for P2 … P5 …
git tag p2-queries p3-txn p4-nosql p5-distributed
```

See each portfolio's own README for the exact commit command.
