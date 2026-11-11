// =============================================================================
// Portfolio 4 — js/04_aggregations.js
// TestPoint CBT — MongoDB aggregations.
//
// Three aggregations:
//   A1. Questions per subject and difficulty.
//   A2. Average score per question (attempts → questions lookup).
//   A3. (bonus) Pass rate per subject (attempts → questions lookup → group).
//
// Run AFTER the bulk generator (or 03_seed_small.js).
// =============================================================================

db = db.getSiblingDB('testpoint');

print('=== A1. Questions per subject and difficulty ===');
const a1 = db.questions.aggregate([
  { $group: {
      _id: { subject: '$subject', difficulty: '$difficulty' },
      count: { $sum: 1 }
  }},
  { $sort: { '_id.subject': 1, '_id.difficulty': 1 } }
]);
printjson(a1.toArray());

print('');
print('=== A2. Average score per question (top 10 by attempts) ===');
const a2 = db.attempts.aggregate([
  { $group: {
      _id: '$question_id',
      avg_score:    { $avg: '$score' },
      attempt_count:{ $sum: 1 },
      pass_count:   { $sum: { $cond: ['$correct', 1, 0] } }
  }},
  { $sort: { attempt_count: -1 } },
  { $limit: 10 },
  { $lookup: {
      from: 'questions',
      localField: '_id',
      foreignField: '_id',
      as: 'question'
  }},
  { $unwind: '$question' },
  { $project: {
      _id: 0,
      question_id: '$_id',
      subject: '$question.subject',
      topic:   '$question.topic',
      type:    '$question.type',
      avg_score: { $round: ['$avg_score', 2] },
      attempt_count: 1,
      pass_rate: { $round: [{ $multiply: [{ $divide: ['$pass_count', '$attempt_count'] }, 100] }, 2] }
  }}
]);
printjson(a2.toArray());

print('');
print('=== A3. Pass rate per subject (attempts → questions → group by subject) ===');
const a3 = db.attempts.aggregate([
  { $lookup: {
      from: 'questions',
      localField: 'question_id',
      foreignField: '_id',
      as: 'question'
  }},
  { $unwind: '$question' },
  { $group: {
      _id: '$question.subject',
      attempts:     { $sum: 1 },
      pass_count:   { $sum: { $cond: ['$correct', 1, 0] } },
      avg_score:    { $avg: '$score' }
  }},
  { $project: {
      _id: 0,
      subject: '$_id',
      attempts: 1,
      pass_rate_pct: { $round: [{ $multiply: [{ $divide: ['$pass_count', '$attempts'] }, 100] }, 2] },
      avg_score:     { $round: ['$avg_score', 3] }
  }},
  { $sort: { pass_rate_pct: -1 } }
]);
printjson(a3.toArray());

print('');
print('=== A4 (bonus). Question-type distribution per exam body ===');
const a4 = db.questions.aggregate([
  { $group: {
      _id: { exam_body: '$_metadata.exam_body', type: '$type' },
      count: { $sum: 1 }
  }},
  { $sort: { '_id.exam_body': 1, '_id.type': 1 } }
]);
printjson(a4.toArray());

print('=== Aggregations done ===');
