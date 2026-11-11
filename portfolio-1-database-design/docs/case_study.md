# Portfolio 1 — Case study description

**Student:** Emmanuel Onyeama · **Matric:** 2026/A/MIT/0876  
**Course:** MIT 8103 Advanced Database Systems — Miva Open University

## 1. Selected organisation

**TestPoint CBT** is a simulated Nigerian company that operates computer-based
test (CBT) centres across five cities:

| Centre code | City    | Capacity (computers) |
|-------------|---------|----------------------|
| LOS-01      | Lagos   | 120 |
| ABJ-01      | Abuja   | 100 |
| IBD-01      | Ibadan  |  80 |
| ENU-01      | Enugu   |  60 |
| KAN-01      | Kano    |  90 |

TestPoint delivers two broad families of exams:

1. **Professional certifications** — PMP, ACCA (F6 Taxation), ICAN PE1, Cisco
   CCNA, Microsoft AZ-900, AWS Cloud Practitioner.
2. **Recruitment tests** — NNPC Graduate Recruitment, CBN Aptitude Test.
3. **Language tests** — TOEFL iBT, IELTS Academic.

## 2. Users of the database

| User | What they do with the database |
|---|---|
| Candidates | Register, pick centre + session, pay, check in, receive results |
| Invigilators | Mark attendance / check-in on exam day |
| Centre managers | See utilisation, plan sessions, maintain seats |
| Accounts / Finance | Reconcile payments, revenue per centre |
| Exam body auditors | Verify that no seat was double-booked, capacity respected |
| TestPoint scheduler | Decide how many sessions to open per centre per day |

## 3. Major data stored (the 9 tables)

`centre`, `exam`, `exam_session`, `seat`, `candidate`, `registration`,
`seat_allocation`, `payment`, `result`.

## 4. Key operations supported

- Candidate registers for an exam.
- Scheduler opens sessions (centre + exam + date + start/end time).
- The system allocates a specific seat (computer) to a candidate in a session.
- Candidate pays; payment is recorded.
- On exam day the candidate checks in and sits; afterwards a score is recorded.
- Reports: free seats per session, centre utilisation, pass rate, no-show
  rate, revenue per centre, candidates per exam per month (Portfolio 2).

## 5. Why this case study

CBT scheduling is a textbook fit for advanced database concepts:

- **Concurrency** — two candidates racing for the last seat (Portfolio 3).
- **Constraints** — no double-booking, no overlapping sessions, capacity
  triggers (Portfolio 1).
- **Optimisation** — reporting across 50k+ allocations (Portfolio 2).
- **NoSQL** — the question bank has heterogeneous question shapes (Portfolio 4).
- **Distributed / cloud** — exam-day traffic peaks, data residency under the
  Nigeria Data Protection Act 2023 (Portfolio 5).
