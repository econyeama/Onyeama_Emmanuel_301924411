// =============================================================================
// Portfolio 4 — js/05_index_demo.js
// TestPoint CBT — COLLSCAN → IXSCAN demonstration.
//
// We pick a realistic filter — "give me all hard Mathematics questions set
// by the NNPC" — and run explain("executionStats") on it:
//   1. BEFORE creating the index  → COLLSCAN (collection scan).
//   2. AFTER  creating the index  → IXSCAN  (index scan).
//
// The winningPlan.stage tells the story:
//   COLLSCAN  ⇒ the engine read every document.
//   IXSCAN    ⇒ the engine used the B-tree index.
//
// Run AFTER the bulk generator (or 03_seed_small.js) so there is data to scan.
// =============================================================================

db = db.getSiblingDB('testpoint');

// Drop any pre-existing index on these fields for a clean BEFORE.
db.questions.dropIndex('idx_subject_difficulty_1');
db.questions.dropIndex('subject_1_difficulty_1');

const FILTER = { subject: 'Mathematics', difficulty: 'hard' };

print('=== BEFORE index — explain() ===');
const before = db.questions.find(FILTER).explain('executionStats');
print('winningPlan.stage      : ' + before.queryPlanner.winningPlan.stage);
print('executionStats.totalDocsExamined : ' + before.executionStats.totalDocsExamined);
print('executionStats.nReturned         : ' + before.executionStats.nReturned);
print('executionStats.executionTimeMillis: ' + before.executionStats.executionTimeMillis);
print('');
print('--- full winningPlan (before) ---');
printjson(before.queryPlanner.winningPlan);

print('');
print('=== Creating compound index { subject: 1, difficulty: 1 } ===');
db.questions.createIndex({ subject: 1, difficulty: 1 },
                         { name: 'idx_subject_difficulty_1' });

print('');
print('=== AFTER index — explain() ===');
const after = db.questions.find(FILTER).explain('executionStats');
print('winningPlan.stage      : ' + after.queryPlanner.winningPlan.stage);
if (after.queryPlanner.winningPlan.inputStage) {
  print('inputStage.stage       : ' + after.queryPlanner.winningPlan.inputStage.stage);
  print('inputStage.indexName   : ' + after.queryPlanner.winningPlan.inputStage.indexName);
}
print('executionStats.totalDocsExamined : ' + after.executionStats.totalDocsExamined);
print('executionStats.nReturned         : ' + after.executionStats.nReturned);
print('executionStats.executionTimeMillis: ' + after.executionStats.executionTimeMillis);
print('');
print('--- full winningPlan (after) ---');
printjson(after.queryPlanner.winningPlan);

print('');
print('=== Indexes on questions collection ===');
printjson(db.questions.getIndexes());

print('');
print('=== BEFORE / AFTER summary ===');
print('Stage    BEFORE: ' + before.queryPlanner.winningPlan.stage +
      ' | AFTER: ' + after.queryPlanner.winningPlan.stage +
      ' (inputStage: ' + (after.queryPlanner.winningPlan.inputStage
                          ? after.queryPlanner.winningPlan.inputStage.stage
                          : 'n/a') + ')');
print('Docs     BEFORE: ' + before.executionStats.totalDocsExamined +
      ' | AFTER: ' + after.executionStats.totalDocsExamined);
print('Time ms  BEFORE: ' + before.executionStats.executionTimeMillis +
      ' | AFTER: ' + after.executionStats.executionTimeMillis);
