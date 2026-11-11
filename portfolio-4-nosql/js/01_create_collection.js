// =============================================================================
// Portfolio 4 — js/01_create_collection.js
// TestPoint CBT — MongoDB question bank.
//
// Creates the two collections used by this portfolio:
//   * questions  — the question bank (4 different shapes: mcq, true_false,
//                  fill_in, short_answer).
//   * attempts   — one document per candidate attempt at a question, used by
//                  the "average score per question" aggregation.
//
// Run with mongosh:
//   mongosh mongodb://127.0.0.1:27017/testpoint --quiet js/01_create_collection.js
// =============================================================================

db = db.getSiblingDB('testpoint');

print('=== Creating collections ===');

db.createCollection('questions');
db.createCollection('attempts');

// Drop indexes from a previous run (so the index demo is reproducible).
db.questions.dropIndexes();
db.attempts.dropIndexes();

print('questions count : ' + db.questions.countDocuments());
print('attempts  count : ' + db.attempts.countDocuments());
print('=== Collections ready ===');
