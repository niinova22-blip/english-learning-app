# Authoring English-medium packages (Business English, Everyday English)

Audience: learners worldwide. Everything is written in English; there is no
Turkish anywhere (`translationTR` is always `""`). Lint + assemble with
`scripts/assemble-package.py` (see its docstring). Validate a single unit with:
`PY scripts/assemble-package.py --unit content/<pkg>/units/<file>.json <pkg>`
(PY = `C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe`).

## Unit shape (every unit, both packages)

File `content/<pkg>/units/NN-<slug>.json`, `NN` = 01..08, `order` = NN-1.
Lessons in this order (`order` 0..4):

| order | lesson id | skill | content |
|---|---|---|---|
| 0 | `<p>uNN-vocab-1` | vocabulary | 10 vocabulary items |
| 1 | `<p>uNN-vocab-2` | vocabulary | 10 vocabulary items |
| 2 | `<p>uNN-vocab-3` | vocabulary | 10 vocabulary items |
| 3 | `<p>uNN-grammar` | grammar | 1 `grammarPoint` card + 8 questions, kind `grammar` |
| 4 | `<p>uNN-practice` | reading | 1 `practiceSet` card + 6-8 questions (kind per unit table) |

`<p>` = `biz-` or `day-`. Unit id `<p>unit-NN-<slug>`. Item id `<p>item-<headword-slug>`
(multi-word: hyphens). Question id `<lesson id>-qNN` (q01..). Passage id
`<lesson id>-passage`. `estimatedDurationMinutes`: vocab 6, grammar 8, practice 8.
Lesson `title`: short, e.g. "Meetings I", "Meetings II", "Meetings III",
"Grammar: Modals for suggestions", "Reading: A company profile" / "Dialogues: …" / "Email gaps: …".

### Vocabulary item
```json
{"id": "biz-item-agenda", "type": "vocabulary", "headword": "agenda",
 "frequencyRank": 4200, "baseDifficulty": 0.45,
 "definition": "a list of the things that people will discuss at a meeting",
 "exampleSentences": ["The first item on the agenda is the new budget.",
                      "Could you send me the agenda before Friday's meeting?"],
 "translationTR": "",
 "collocations": ["set the agenda", "on the agenda", "a packed agenda"]}
```
- `definition`: learner's-dictionary style, simple words (A2 package: very simple),
  never starts with or repeats the headword, lower-case start, no final period.
- 2-3 natural example sentences that USE the headword (an inflected form is fine:
  agenda/agendas, negotiate/negotiated — the lint checks the stem), each showing
  a typical context. No two examples with the same pattern.
- 2-4 real, frequent collocations (check they are idiomatic).
- `frequencyRank`: approximate rank in general English (common word 500-3000,
  business terms 3000-15000). `baseDifficulty` 0.05-0.95: A2 ≈ 0.1-0.35,
  B1 ≈ 0.3-0.5, B2 ≈ 0.5-0.7, C1 ≈ 0.7-0.9.
- Headwords are unique within the package; phrasal verbs and fixed phrases
  ("follow up", "on schedule") are welcome, especially in Everyday English.

### Grammar lesson
Card: `{"id": "<p>item-grammar-<slug>", "type": "grammarPoint", "headword": "<topic>",
"frequencyRank": 1000+NN, "baseDifficulty": 0.4, "definition": "<one-line summary>",
"exampleSentences": [], "translationTR": "", "collocations": [],
"explanationTR": "<the lesson text in ENGLISH, 120-220 words, short paragraphs and • bullets with \n, rules + 3-5 examples in the unit's context>"}`
Questions: 8, kind `grammar`, one gap `----` in `prompt` (or a full-sentence
choice), 5 options, set in the unit's topic. Each tests the unit's grammar point.

### Practice lesson
Card: `type: practiceSet`, headword = the lesson's subject ("A company profile"),
definition = one line ("A short article about a family business and six questions"),
no explanationTR needed. `reading` kind: add
`"passage": {"id": "...-passage", "title": "...", "body": "..."}` (Business 220-320
words; Everyday 140-220 words, simple language) and every question has
`"passageID"`. `dialogueCompletion`: prompt is a short 2-4 line dialogue with
one `----` line; options are replies. `cloze`: prompt is 1-2 sentences of an
email/message with one `----` gap; options are words/phrases.

### Every question
- 5 options, exactly one clearly correct; distractors plausible for a learner,
  wrong for a clear reason; no "all of the above".
- Options of similar length and form; the key must NOT be the longest option in
  more than half of a unit's questions (lint enforces), and keys spread over A-E
  (no letter > 40% within a lesson).
- `explanationTR` (English!): 1-3 sentences: why the key is right and why the
  most tempting distractor is wrong.
- Natural, modern, internationally neutral English (no UK/US-only slang; spelling
  consistently American). Names and places diverse. No brands, politics, religion.

## Business English (biz-, B1-C1)

| NN | slug / theme | grammar | practice (kind) |
|---|---|---|---|
| 01 | workplace — "At work: roles and routines" | Present simple vs present continuous | Reading: a company profile (reading) |
| 02 | meetings — "Meetings" | Modals for suggestions and opinions | Dialogues: in a meeting (dialogueCompletion) |
| 03 | emails — "Emails and correspondence" | Polite requests and indirect questions | Email gaps (cloze) |
| 04 | presentations — "Presentations" | Comparatives and superlatives for trends | Reading: a presentation script (reading) |
| 05 | negotiation — "Negotiation and sales" | First and second conditionals | Dialogues: negotiating a deal (dialogueCompletion) |
| 06 | finance — "Finance and performance" | Present perfect vs past simple for results | Reading: a quarterly report (reading) |
| 07 | marketing — "Marketing and customers" | The passive in reports | Gaps: a marketing article (cloze) |
| 08 | projects — "Projects and careers" | Future forms for plans and deadlines | Reading: a project update (reading) |

Level: units 01-03 mostly B1-B2, 04-08 B2-C1. Vocabulary: the core, frequent
words of each theme (e.g. meetings: agenda, minutes, chair, postpone, consensus,
action item, attendee, adjourn, brainstorm, follow up ...).

## Everyday English (day-, A2-B1)

| NN | slug / theme | grammar | practice (kind) |
|---|---|---|---|
| 01 | daily-life — "Daily life and routines" | Present simple with adverbs of frequency | Dialogues: a normal day (dialogueCompletion) |
| 02 | food — "Food and eating out" | Countable and uncountable nouns: some, any, much, many | Dialogues: at a restaurant (dialogueCompletion) |
| 03 | shopping — "Shopping and money" | Comparatives and superlatives | Reading: smart shopping tips (reading) |
| 04 | travel — "Travel and directions" | Past simple: regular and irregular verbs | Dialogues: asking for directions (dialogueCompletion) |
| 05 | home — "Home and neighborhood" | There is / there are and prepositions of place | Gaps: a message to a neighbor (cloze) |
| 06 | health — "Health and the body" | Should, must and have to | Dialogues: at the doctor's (dialogueCompletion) |
| 07 | people — "People and relationships" | Future plans: going to and present continuous | Reading: an email from a friend (reading) |
| 08 | free-time — "Free time and feelings" | Present perfect for experiences | Reading: a hobby that changed my life (reading) |

Level: A2 (units 01-04) to B1 (05-08). Vocabulary: high-frequency everyday words
and phrases (e.g. daily life: wake up, commute, chore, lunch break, laundry,
grocery, get dressed, bedtime, usually, weekend ...). Keep definitions and
examples very plain.
