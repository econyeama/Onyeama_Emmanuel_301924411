// =============================================================================
// Portfolio 4 — js/02_schema_validation.js
// TestPoint CBT — JSON Schema validation for the question bank.
//
// The collection intentionally stores FOUR different question shapes, each
// discriminated by the `type` field:
//
//   mcq          — multiple choice: options[] + correct_index
//   true_false   — boolean answer: correct_answer (bool)
//   fill_in      — text answer:   acceptable_answers[] (regex strings)
//   short_answer — model answer + marks (numeric)
//
// The $jsonSchema validator uses oneOf so that ONLY the fields appropriate
// to each type are required, while the common fields (type, subject,
// difficulty, question, _metadata) are always required.
//
// Validation level: 'strict' (default) — invalid inserts are rejected.
// Validation action: 'error' (default) — invalid inserts ERROR out.
// =============================================================================

db = db.getSiblingDB('testpoint');

print('=== Installing JSON schema validator on questions ===');

db.runCommand({
  collMod: 'questions',
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['type', 'subject', 'topic', 'difficulty', 'question', '_metadata'],
      properties: {
        type:       { enum: ['mcq', 'true_false', 'fill_in', 'short_answer'] },
        subject:    { bsonType: 'string' },
        topic:      { bsonType: 'string' },
        difficulty: { enum: ['easy', 'medium', 'hard'] },
        question:   { bsonType: 'string' },
        _metadata: {
          bsonType: 'object',
          required: ['exam_body', 'created_at'],
          properties: {
            exam_body:     { bsonType: 'string' },
            created_at:    { bsonType: 'date' },
            image_url:     { bsonType: ['string', 'null'] },
            tags:          { bsonType: ['array', 'null'] },
            source:        { bsonType: ['string', 'null'] }
          }
        }
      },
      // Discriminated union: depending on `type`, the right extra fields are required.
      oneOf: [
        {
          properties: {
            type:           { enum: ['mcq'] },   // ($jsonSchema has no 'const'; a one-value enum does the same)
            options:        { bsonType: 'array', minItems: 2, maxItems: 6,
                              items: { bsonType: 'string' } },
            correct_index:  { bsonType: 'int', minimum: 0 }
          },
          required: ['options', 'correct_index']
        },
        {
          properties: {
            type:           { enum: ['true_false'] },   // ($jsonSchema has no 'const'; a one-value enum does the same)
            correct_answer: { bsonType: 'bool' }
          },
          required: ['correct_answer']
        },
        {
          properties: {
            type:                { enum: ['fill_in'] },   // ($jsonSchema has no 'const'; a one-value enum does the same)
            acceptable_answers:  { bsonType: 'array', minItems: 1, maxItems: 10,
                                   items: { bsonType: 'string' } },
            case_sensitive:      { bsonType: ['bool', 'null'] }
          },
          required: ['acceptable_answers']
        },
        {
          properties: {
            type:         { enum: ['short_answer'] },   // ($jsonSchema has no 'const'; a one-value enum does the same)
            model_answer: { bsonType: 'string' },
            marks:        { bsonType: 'int', minimum: 1, maximum: 20 }
          },
          required: ['model_answer', 'marks']
        }
      ]
    }
  },
  validationLevel: 'strict',
  validationAction: 'error'
});

print('=== Validator installed. Testing with valid + invalid documents ===');

// Clean slate for the validator tests.
db.questions.deleteMany({});

// ---- valid MCQ ----
try {
  db.questions.insertOne({
    type: 'mcq',
    subject: 'Numerical Reasoning',
    topic: 'Percentages',
    difficulty: 'easy',
    question: 'What is 15% of 200?',
    options: ['15', '30', '45', '60'],
    correct_index: 1,
    _metadata: { exam_body: 'NNPC', created_at: new Date(),
                 image_url: null, tags: ['arithmetic'], source: 'NNPC 2024 past' }
  });
  print('PASS: valid MCQ accepted');
} catch (e) { print('FAIL: valid MCQ rejected: ' + e.message); }

// ---- valid true/false ----
try {
  db.questions.insertOne({
    type: 'true_false',
    subject: 'Current Affairs',
    topic: 'Nigerian Government',
    difficulty: 'medium',
    question: 'The Nigerian Senate has 109 members.',
    correct_answer: true,
    _metadata: { exam_body: 'CBN', created_at: new Date(),
                 image_url: null, tags: ['civics'], source: 'Constitution' }
  });
  print('PASS: valid true/false accepted');
} catch (e) { print('FAIL: valid true/false rejected: ' + e.message); }

// ---- valid fill_in ----
try {
  db.questions.insertOne({
    type: 'fill_in',
    subject: 'English Language',
    topic: 'Grammar',
    difficulty: 'hard',
    question: 'The past participle of "go" is ____.',
    acceptable_answers: ['gone', 'Gone', 'GONE'],
    case_sensitive: false,
    _metadata: { exam_body: 'IELTS', created_at: new Date(),
                 image_url: null, tags: ['verb-forms'], source: 'IELTS prep' }
  });
  print('PASS: valid fill_in accepted');
} catch (e) { print('FAIL: valid fill_in rejected: ' + e.message); }

// ---- valid short_answer with image ----
try {
  db.questions.insertOne({
    type: 'short_answer',
    subject: 'IT Fundamentals',
    topic: 'Networking',
    difficulty: 'medium',
    question: 'In the OSI model, which layer is responsible for routing?',
    model_answer: 'The Network layer (Layer 3) is responsible for routing...',
    marks: 5,
    _metadata: { exam_body: 'CCNA', created_at: new Date(),
                 image_url: 'https://cdn.testpoint.ng/osi-diagram.png',
                 tags: ['osi', 'routing'], source: 'Cisco NetAcad' }
  });
  print('PASS: valid short_answer (with image) accepted');
} catch (e) { print('FAIL: valid short_answer rejected: ' + e.message); }

// ---- INVALID: mcq missing correct_index ----
try {
  db.questions.insertOne({
    type: 'mcq',
    subject: 'Mathematics',
    topic: 'Algebra',
    difficulty: 'easy',
    question: 'Solve 2x = 10.',
    options: ['2', '5', '10', '20'],
    // correct_index deliberately missing
    _metadata: { exam_body: 'NNPC', created_at: new Date(), image_url: null }
  });
  print('FAIL: invalid MCQ (no correct_index) was accepted');
} catch (e) {
  print('PASS: invalid MCQ rejected — ' + e.message.split('\n')[0]);
}

// ---- INVALID: difficulty not in enum ----
try {
  db.questions.insertOne({
    type: 'true_false',
    subject: 'Mathematics',
    topic: 'Algebra',
    difficulty: 'trivial',   // not in enum
    question: '1 + 1 = 2.',
    correct_answer: true,
    _metadata: { exam_body: 'NNPC', created_at: new Date(), image_url: null }
  });
  print('FAIL: invalid difficulty was accepted');
} catch (e) {
  print('PASS: invalid difficulty rejected — ' + e.message.split('\n')[0]);
}

// ---- INVALID: fill_in with empty acceptable_answers ----
try {
  db.questions.insertOne({
    type: 'fill_in',
    subject: 'English Language',
    topic: 'Vocabulary',
    difficulty: 'easy',
    question: 'A synonym for "happy" is ____.',
    acceptable_answers: [],   // minItems: 1 → reject
    _metadata: { exam_body: 'IELTS', created_at: new Date(), image_url: null }
  });
  print('FAIL: empty acceptable_answers was accepted');
} catch (e) {
  print('PASS: empty acceptable_answers rejected — ' + e.message.split('\n')[0]);
}

print('=== Schema validation tests done. questions count: ' +
      db.questions.countDocuments() + ' ===');
