#!/usr/bin/env python3
"""
Portfolio 4 — bulk_data/generate_questions.py
TestPoint CBT — MongoDB bulk question-bank generator.

Produces:
    * 42,000 questions   across 4 shapes (mcq, true_false, fill_in, short_answer)
                         spread over 12 subjects, varied difficulty, ~15 % with image_url
    * ~120,000 attempts  (each question gets 0–10 attempts; not every question is attempted)

Each question document matches the JSON schema validator installed in
js/02_schema_validation.js, so the bulk insert will succeed.

Connection: mongodb://127.0.0.1:27017 (Codespaces default).

Run AFTER js/01_create_collection.js + js/02_schema_validation.js.

Usage:
    python3 portfolio-4-nosql/bulk_data/generate_questions.py

Override the random seed for reproducibility:
    QB_SEED=20260901 python3 .../generate_questions.py
"""

import os
import random
from datetime import datetime, timedelta, timezone

from pymongo import MongoClient, ASCENDING
from pymongo.errors import BulkWriteError

SEED = int(os.environ.get("QB_SEED", "20260901"))
random.seed(SEED)

MONGO_URL = os.environ.get("MONGO_URL", "mongodb://127.0.0.1:27017")
DB_NAME = os.environ.get("MONGO_DB", "testpoint")

# ---------------------------------------------------------------------------
# Subject / topic / template pools. The question text is templated so we get
# realistic-looking content without inventing real exam questions.
# ---------------------------------------------------------------------------
SUBJECTS_TOPICS = {
    "Mathematics": ["Algebra", "Geometry", "Trigonometry", "Calculus",
                    "Statistics", "Probability"],
    "English Language": ["Grammar", "Vocabulary", "Comprehension",
                         "Essay Structure", "Synonyms", "Antonyms"],
    "Numerical Reasoning": ["Percentages", "Ratios", "Series",
                            "Time-Speed-Distance", "Data Interpretation"],
    "Verbal Reasoning": ["Analogies", "Coding-Decoding", "Logical Deduction",
                         "Syllogisms", "Blood Relations"],
    "Current Affairs": ["Nigerian Government", "Geography", "History",
                        "Economy", "International Relations"],
    "IT Fundamentals": ["Hardware", "Software", "Networking",
                        "Cloud", "Security", "Databases"],
    "Project Management": ["Risk", "Scope", "Schedule", "Cost",
                           "Quality", "Stakeholders"],
    "Accounting": ["Bookkeeping", "Financial Statements", "Taxation",
                   "Auditing", "Cost Accounting"],
    "Networking": ["OSI Model", "TCP/IP", "Routing", "Switching", "DNS"],
    "Cloud Computing": ["Azure", "AWS", "GCP", "Service Models", "Containers"],
    "Quantitative Reasoning": ["Number Series", "Averages", "Mixtures",
                               "Profit-Loss", "Interest"],
    "General Knowledge": ["Sports", "Science", "Literature",
                          "Arts", "Technology"],
}

EXAM_BODIES = ["NNPC", "CBN", "FIRS", "ICAN", "ACCA", "PMI", "Cisco",
               "Microsoft", "ETS", "British Council", "WAEC", "NECO", "Dragnet"]

# Question-text templates per type. The {n} / {topic} placeholders make the
# text unique-ish so we don't get a wall of identical strings.
MCQ_TEMPLATES = [
    "In {topic}, what is the result of operation #{n}?",
    "Which of the following best describes {topic} concept #{n}?",
    "Question {n} on {topic}: identify the correct option below.",
    "Topic: {topic}. Find the value that satisfies condition #{n}.",
    "For {topic}, statement #{n} is:",
]

TRUE_FALSE_TEMPLATES = [
    "Statement {n} on {topic} is correct.",
    "In {topic}, assertion #{n} is true.",
    "Topic: {topic}. The following claim #{n} holds.",
    "{topic} — proposition {n} is valid.",
]

FILL_IN_TEMPLATES = [
    "In {topic}, the missing term in #{n} is ____.",
    "Complete: {topic} definition #{n} ends with ____.",
    "The value of the unknown in {topic} problem #{n} is ____.",
    "{topic}: fill the gap in equation #{n}.",
]

SHORT_ANSWER_TEMPLATES = [
    "Explain {topic} concept #{n} in 2-3 sentences.",
    "Describe how {topic} applies to scenario #{n}.",
    "{topic} — justify your answer to problem #{n}.",
    "Discuss {topic} with reference to example #{n}.",
]

TYPE_WEIGHTS = [("mcq", 0.50), ("true_false", 0.20),
                ("fill_in", 0.20), ("short_answer", 0.10)]
DIFFICULTIES = ["easy", "medium", "hard"]


def pick_type():
    r = random.random()
    acc = 0.0
    for t, w in TYPE_WEIGHTS:
        acc += w
        if r <= acc:
            return t
    return TYPE_WEIGHTS[-1][0]


def make_question(n):
    subject = random.choice(list(SUBJECTS_TOPICS.keys()))
    topic = random.choice(SUBJECTS_TOPICS[subject])
    qtype = pick_type()
    difficulty = random.choices(DIFFICULTIES, weights=[4, 4, 2], k=1)[0]
    exam_body = random.choice(EXAM_BODIES)
    created_at = datetime.now(timezone.utc) - timedelta(days=random.randint(0, 730))
    image_url = None
    if random.random() < 0.15:
        image_url = f"https://cdn.testpoint.ng/q-images/{subject.lower().replace(' ', '-')}/{n}.png"
    tags = [topic.lower().replace(" ", "-"), subject.lower().replace(" ", "-")]
    source = f"{exam_body} past questions"

    base = {
        "type": qtype,
        "subject": subject,
        "topic": topic,
        "difficulty": difficulty,
        "question": "",
        "_metadata": {
            "exam_body": exam_body,
            "created_at": created_at,
            "image_url": image_url,
            "tags": tags,
            "source": source,
        },
    }

    if qtype == "mcq":
        base["question"] = random.choice(MCQ_TEMPLATES).format(topic=topic, n=n)
        n_opts = random.randint(4, 5)
        base["options"] = [f"Option {chr(65 + i)} (q{n}-{i})" for i in range(n_opts)]
        base["correct_index"] = random.randint(0, n_opts - 1)
    elif qtype == "true_false":
        base["question"] = random.choice(TRUE_FALSE_TEMPLATES).format(topic=topic, n=n)
        base["correct_answer"] = random.random() > 0.5
    elif qtype == "fill_in":
        base["question"] = random.choice(FILL_IN_TEMPLATES).format(topic=topic, n=n)
        base["acceptable_answers"] = [f"answer-{n}-a", f"Answer-{n}-A", f"ANSWER-{n}"]
        base["case_sensitive"] = False
    elif qtype == "short_answer":
        base["question"] = random.choice(SHORT_ANSWER_TEMPLATES).format(topic=topic, n=n)
        base["model_answer"] = f"Model answer for {topic} question {n}: ..."
        base["marks"] = random.choice([3, 5, 5, 10, 10, 15])
    return base


def main():
    print(f"[qb] connecting to MongoDB {MONGO_URL} / db={DB_NAME}")
    client = MongoClient(MONGO_URL, serverSelectionTimeoutMS=10000)
    db = client[DB_NAME]

    print("[qb] dropping existing questions + attempts for a clean run")
    db.questions.delete_many({})
    db.attempts.delete_many({})
    # Drop indexes from a previous run (so the index demo is reproducible).
    try: db.questions.drop_index("idx_subject_difficulty_1")
    except Exception: pass

    N_QUESTIONS = 42000
    print(f"[qb] generating {N_QUESTIONS:,} questions …")

    BATCH = 2000
    docs = []
    inserted = 0
    qids = []
    for i in range(1, N_QUESTIONS + 1):
        docs.append(make_question(i))
        if len(docs) >= BATCH:
            res = db.questions.insert_many(docs, ordered=False)
            qids.extend(res.inserted_ids)
            inserted += len(docs)
            print(f"[qb]   inserted {inserted:,} / {N_QUESTIONS}")
            docs = []
    if docs:
        res = db.questions.insert_many(docs, ordered=False)
        qids.extend(res.inserted_ids)
        inserted += len(docs)
    print(f"[qb]   total questions inserted: {inserted:,}")

    # ---- Attempts: each question gets 0–10 attempts (~5 avg) ----
    print("[qb] generating attempts (~5 per question on average) …")
    attempt_batch = []
    attempt_count = 0
    n_candidates = 12000
    for qid in qids:
        n_att = random.choices([0, 1, 2, 3, 5, 7, 10], weights=[3, 2, 2, 2, 2, 2, 1], k=1)[0]
        for _ in range(n_att):
            score = round(random.triangular(0, 1, 0.6), 2)
            attempt_batch.append({
                "question_id": qid,
                "candidate_id": random.randint(1, n_candidates),   # same ids as PostgreSQL candidates
                "score": score,
                "correct": score >= 0.5,                           # consistent with the score
                "attempted_at": datetime.now(timezone.utc) - timedelta(days=random.randint(0, 365)),
            })
        if len(attempt_batch) >= BATCH:
            db.attempts.insert_many(attempt_batch, ordered=False)
            attempt_count += len(attempt_batch)
            print(f"[qb]   inserted {attempt_count:,} attempts")
            attempt_batch = []
    if attempt_batch:
        db.attempts.insert_many(attempt_batch, ordered=False)
        attempt_count += len(attempt_batch)
    print(f"[qb]   total attempts inserted: {attempt_count:,}")

    # ---- Verification ----
    print("")
    print("==============================================================")
    print(" MONGODB BULK DATA SUMMARY — TestPoint CBT question bank")
    print("==============================================================")
    print(f" questions        : {db.questions.count_documents({}):,}")
    print(f" attempts         : {db.attempts.count_documents({}):,}")
    print(" by type:")
    for r in db.questions.aggregate([
        {"$group": {"_id": "$type", "count": {"$sum": 1}}},
        {"$sort": {"_id": 1}}
    ]):
        print(f"   {r['_id']:<14}: {r['count']:>6,}")
    print(" by difficulty:")
    for r in db.questions.aggregate([
        {"$group": {"_id": "$difficulty", "count": {"$sum": 1}}},
        {"$sort": {"_id": 1}}
    ]):
        print(f"   {r['_id']:<14}: {r['count']:>6,}")
    print(" by subject (top 12):")
    for r in db.questions.aggregate([
        {"$group": {"_id": "$subject", "count": {"$sum": 1}}},
        {"$sort": {"count": -1}},
        {"$limit": 12}
    ]):
        print(f"   {r['_id']:<24}: {r['count']:>6,}")
    print("==============================================================")
    print("[qb] DONE. Screenshot this terminal output for your evidence.")


if __name__ == "__main__":
    main()
