// =============================================================================
// Portfolio 4 — js/03_seed_small.js
// TestPoint CBT — small readable seed for the question bank + attempts.
//
// Inserts one example of each of the 4 question shapes plus a few attempts,
// so that running the aggregations in 04_aggregations.js without the bulk
// generator still produces non-empty output.
//
// Run AFTER 02_schema_validation.js (the validator must already be in place).
// =============================================================================

db = db.getSiblingDB('testpoint');

// Keep the validator-installed documents; just add a few more.
print('=== Seeding small readable dataset ===');

// MCQ × 3
db.questions.insertMany([
  {
    type: 'mcq', subject: 'Numerical Reasoning', topic: 'Percentages',
    difficulty: 'easy', question: 'What is 20% of 450?',
    options: ['45', '90', '120', '180'], correct_index: 1,
    _metadata: { exam_body: 'NNPC', created_at: new Date(),
                 image_url: null, tags: ['arithmetic'], source: 'NNPC 2023' }
  },
  {
    type: 'mcq', subject: 'IT Fundamentals', topic: 'Cloud',
    difficulty: 'medium', question: 'Which Azure service is an IaaS VM?',
    options: ['Azure Functions', 'Azure Virtual Machines',
              'Azure Blob Storage', 'Azure Cosmos DB'],
    correct_index: 1,
    _metadata: { exam_body: 'AZ-900', created_at: new Date(),
                 image_url: null, tags: ['azure', 'iaas'], source: 'Microsoft Learn' }
  },
  {
    type: 'mcq', subject: 'Mathematics', topic: 'Geometry',
    difficulty: 'hard',
    question: 'A circle has radius 7. What is its area (π = 22/7)?',
    options: ['44', '154', '49', '308'], correct_index: 1,
    _metadata: { exam_body: 'WAEC', created_at: new Date(),
                 image_url: 'https://cdn.testpoint.ng/circle-r7.png',
                 tags: ['circle', 'area'], source: 'WAEC past' }
  }
]);

// true/false × 2
db.questions.insertMany([
  {
    type: 'true_false', subject: 'Current Affairs', topic: 'Geography',
    difficulty: 'easy', question: 'Lagos was the capital of Nigeria until 1991.',
    correct_answer: true,
    _metadata: { exam_body: 'CBN', created_at: new Date(),
                 image_url: null, tags: ['history'], source: 'Constitution' }
  },
  {
    type: 'true_false', subject: 'IT Fundamentals', topic: 'Networking',
    difficulty: 'medium',
    question: 'TCP operates at the Transport layer of the OSI model.',
    correct_answer: true,
    _metadata: { exam_body: 'CCNA', created_at: new Date(),
                 image_url: null, tags: ['osi', 'tcp'], source: 'Cisco NetAcad' }
  }
]);

// fill_in × 2
db.questions.insertMany([
  {
    type: 'fill_in', subject: 'English Language', topic: 'Vocabulary',
    difficulty: 'easy', question: 'The capital of Nigeria is ____.',
    acceptable_answers: ['Abuja', 'abuja', 'ABUJA'], case_sensitive: false,
    _metadata: { exam_body: 'IELTS', created_at: new Date(),
                 image_url: null, tags: ['geography'], source: 'IELTS prep' }
  },
  {
    type: 'fill_in', subject: 'Mathematics', topic: 'Algebra',
    difficulty: 'medium', question: 'If 3x + 2 = 11, then x = ____.',
    acceptable_answers: ['3'], case_sensitive: false,
    _metadata: { exam_body: 'NNPC', created_at: new Date(),
                 image_url: null, tags: ['linear-equation'], source: 'NNPC past' }
  }
]);

// short_answer × 2
db.questions.insertMany([
  {
    type: 'short_answer', subject: 'Project Management', topic: 'Risk',
    difficulty: 'hard',
    question: 'Explain the difference between a risk and an issue in 2-3 sentences.',
    model_answer: 'A risk is a future uncertain event that may positively or negatively affect ...',
    marks: 5,
    _metadata: { exam_body: 'PMP', created_at: new Date(),
                 image_url: null, tags: ['risk', 'issues'], source: 'PMBOK 7' }
  },
  {
    type: 'short_answer', subject: 'Accounting', topic: 'Taxation',
    difficulty: 'medium',
    question: 'Define Value Added Tax (VAT) and state the current Nigerian VAT rate.',
    model_answer: 'VAT is a consumption tax on the value added ... current rate 7.5%.',
    marks: 10,
    _metadata: { exam_body: 'ICAN', created_at: new Date(),
                 image_url: null, tags: ['vat', 'tax'], source: 'FIRS 2024' }
  }
]);

print('questions count after small seed: ' + db.questions.countDocuments());

// A few attempts so the avg-score aggregation has something to chew on.
const sampleQs = db.questions.find({}, { _id: 1 }).limit(5).toArray();
const attempts = [];
for (let i = 0; i < sampleQs.length; i++) {
  for (let j = 0; j < 10; j++) {
    attempts.push({
      question_id: sampleQs[i]._id,
      candidate_id: 1000 + j,
      score: Math.round(Math.random() * 100) / 100,
      correct: Math.random() > 0.4,
      attempted_at: new Date(Date.now() - Math.floor(Math.random() * 30 * 86400000))
    });
  }
}
db.attempts.insertMany(attempts);
print('attempts count after small seed: ' + db.attempts.countDocuments());
print('=== Small seed done ===');
