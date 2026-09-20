# Vocabulary Expansion and Study Techniques (Slice 7d) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship 3 study-technique units (18 lessons, 118 questions) and 8 vocabulary units (480 new words), as content plus one question-kind label, two assembly tables and the content lint.

**Architecture:** `scripts/assemble-content.py` gains `TECH_UNITS` (technique lesson files, one lesson per file, like `GRAMMAR_UNITS`) and `VOCAB2_FILES` (one unit document per file, like `BATCH_FILES`), emitted after the 13 existing units at orders 13-23. A technique lesson is a `grammarPoint` card with a Turkish `explanationTR` plus questions of kind `strategy` (or `grammar` for prefix/suffix lessons). A vocabulary lesson is ten `vocabulary` items in the existing format. `QuestionKind` gains `strategy`; nothing else in the Swift code changes. Correctness is enforced by per-unit independent review; the Python lint enforces everything mechanical.

**Tech Stack:** Python 3.12 content assembly, JSON content under `content/yds-academic-vocab-1/`, Swift 5.10 / SwiftUI / SwiftData consumers, GitHub Actions macOS runners (`Swift Tests`, `App Build`) for all verification.

**Spec:** `docs/superpowers/specs/2026-09-20-vocabulary-and-study-techniques-design.md`

## Global Constraints

- **No Swift toolchain on this machine.** Never claim a local `swift test` or `xcodebuild` run. Every task's verification is: commit, push, confirm both CI workflows green — `Swift Tests` (`scripts/ci-test.sh`) and `App Build` (`scripts/ci-app-build.sh`). A content-only task still runs both.
- **Pushed commits are never amended.** A mistake found after a push is fixed by a new commit.
- **Every git commit message ends with a blank line and then** `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`. Single-quoted heredocs; avoid backticks and `$(...)` inside double-quoted bash strings. Long Python/Turkish files are written with the Write tool, not Bash heredocs.
- **Real Python only:** `"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py`. Never bare `python`/`python3`. After every run, `git status --short` must show both derived JSON files changed, and `scripts/__pycache__/` must be deleted.
- **Never hand-edit derived JSON:** `App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json` and `LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json`.
- **Tests assert concrete values.** **Ids are stable and never reused.**
- **All learner-facing Turkish is real Turkish** (`ı İ ş ğ ü ö ç`), informal "sen" register, UTF-8, LF.
- **Original text only.** No copyrighted dictionary or exam text; write definitions, examples and passages fresh.
- **Quality rules (binding):**
  1. *Vocabulary entries:* accurate Turkish for the academic sense; polysemy handled honestly (list the senses the academic usage needs); natural B2-C1 example sentences that use the headword or an inflection; collocations that really occur; a `definition` (Turkish, one sentence ending with a full stop) that defines rather than just translates.
  2. *Strategy content:* correct, exam-realistic advice; no invented statistics; **no claim about ÖSYM's scoring or penalty rules** (say "değerlendirme kuralını ÖSYM kılavuzundan oku"); consistent across lessons.
  3. *Questions:* exactly one defensible correct option; every distractor refutable in one sentence; `explanationTR` (2-4 sentences) states the reasoning and names and refutes at least two distractors with correct `(A)`-`(E)` letters; **the correct option is not systematically the longest, and options are of balanced length** (the 7c reviews found this the most common defect); no junk, absurd or ungrammatical distractors; key distribution valid (no key over 40 % of a lesson's questions, never three consecutive).
  4. Stem + KEY reads as a natural sentence; one blank per stem where a blank exists.

---

## Contracts (binding — the lint enforces them)

### Technique lessons

Lesson id `yds-tech-<slug>`; card id `yds-tech-card-<slug>`; question id `yds-tech-<slug>-q<NN>` (`order = NN-1`). One file per lesson under `content/yds-academic-vocab-1/tech/<unit-dir>/<slug>.json`, without an `order` key. Exactly one item, `"type": "grammarPoint"`, with a non-empty Turkish `explanationTR` that **contains the phrase `En sık düşülen tuzak:`**; `exampleSentences: []`, `collocations: []`, `headword` an English label, `frequencyRank` unique from 4000 up, `baseDifficulty` 0.5, `definition` one Turkish line, `translationTR` the Turkish lesson title. No passage; every `passageID` is `null`; five distinct options.

| unit | dir | order | slug | kind | skill | questions | minutes | Turkish title |
|---|---|---|---|---|---|---|---|---|
| `yds-tech-unit-question-strategies` (`Sınav soru tipi stratejileri`) | `question-strategies` | 13 | `reading` | `strategy` | reading | 6 | 7 | `Strateji: Okuma Soruları` |
| | | | `cloze` | `strategy` | reading | 6 | 7 | `Strateji: Cloze Testi` |
| | | | `sentence` | `strategy` | grammar | 6 | 7 | `Strateji: Cümle Tamamlama` |
| | | | `translation` | `strategy` | reading | 6 | 7 | `Strateji: Çeviri Soruları` |
| | | | `paragraph` | `strategy` | reading | 6 | 7 | `Strateji: Paragraf Tamamlama` |
| | | | `irrelevant` | `strategy` | reading | 6 | 7 | `Strateji: Konu Dışı Cümle` |
| | | | `dialogue` | `strategy` | grammar | 6 | 7 | `Strateji: Diyalog Tamamlama` |
| | | | `restatement` | `strategy` | reading | 6 | 7 | `Strateji: Yeniden İfade` |
| | | | `vocabulary-questions` | `strategy` | reading | 6 | 7 | `Strateji: Kelime Soruları` |
| | | | `grammar-questions` | `strategy` | grammar | 6 | 7 | `Strateji: Gramer Soruları` |
| `yds-tech-unit-exam-management` (`Sınav yönetimi ve zaman`) | `exam-management` | 14 | `time-allocation` | `strategy` | reading | 6 | 7 | `Sınav Yönetimi: Zaman Payı` |
| | | | `elimination` | `strategy` | reading | 6 | 7 | `Sınav Yönetimi: Eleme ve Tahmin` |
| | | | `exam-day` | `strategy` | reading | 6 | 7 | `Sınav Yönetimi: Sınav Günü` |
| `yds-tech-unit-vocabulary-skills` (`Kelime öğrenme teknikleri`) | `vocabulary-skills` | 15 | `prefixes` | `grammar` | grammar | 8 | 9 | `Kelime Tekniği: Ön Ekler` |
| | | | `suffixes` | `grammar` | grammar | 8 | 9 | `Kelime Tekniği: Son Ekler` |
| | | | `context-clues` | `strategy` | reading | 8 | 9 | `Kelime Tekniği: Bağlamdan Anlam` |
| | | | `synonyms-collocations` | `strategy` | reading | 8 | 9 | `Kelime Tekniği: Eş Anlam ve Eşdizimlilik` |
| | | | `memorisation` | `strategy` | reading | 8 | 9 | `Kelime Tekniği: Ezberleme ve Tekrar` |

Totals: 18 lessons, 18 `grammarPoint` cards, **118** questions. `frequencyRank` = 4000 + position in this table (4000 … 4017).

### Vocabulary units

One file per unit: `content/yds-academic-vocab-1/vocab2/<unit-slug>.json`, document shape `{id, theme, order, lessons: [{id, order, estimatedDurationMinutes, items}]}` exactly like `batches/*.json`. Lesson id `yds-vocab2-lesson-<slug>-<n>` (`n` 1-6, `order` n-1), `estimatedDurationMinutes` 5, no `skill` key (defaults to vocabulary), no `title` key (derived as `<theme> · <n>`). Item id `yds-vocab2-item-<headword>`; fields `type` `vocabulary`, `headword` (lowercase ASCII letters, hyphens allowed), `frequencyRank` (positive integer), `baseDifficulty` (0.05-0.95), `definition` (Turkish, ends with `.`), `exampleSentences` (exactly 3, each contains the headword's stem), `translationTR`, `collocations` (exactly 3, each contains the headword's stem). "Stem" = `headword[:max(3, len(headword) - 3)]`, compared case-insensitively.

| order | unit id | slug | theme |
|---|---|---|---|
| 16 | `yds-vocab2-unit-health-medicine` | `health-medicine` | `Health & Medicine` |
| 17 | `yds-vocab2-unit-environment-energy` | `environment-energy` | `Environment & Energy` |
| 18 | `yds-vocab2-unit-technology-innovation` | `technology-innovation` | `Technology & Innovation` |
| 19 | `yds-vocab2-unit-education-learning` | `education-learning` | `Education & Learning` |
| 20 | `yds-vocab2-unit-history-culture` | `history-culture` | `History & Culture` |
| 21 | `yds-vocab2-unit-psychology-behaviour` | `psychology-behaviour` | `Psychology & Behaviour` |
| 22 | `yds-vocab2-unit-politics-governance` | `politics-governance` | `Politics & Governance` |
| 23 | `yds-vocab2-unit-media-communication` | `media-communication` | `Media & Communication` |

`frequencyRank` of the k-th word (0-based) of unit order `o` = `100 + (o - 16) * 60 + k`. `baseDifficulty` is computed by the helper: lesson `n` base `0.25 + 0.1 * (n - 1)` plus a per-word offset `[-0.04, -0.03, -0.02, -0.01, 0, 0.01, 0.02, 0.03, 0.04, 0.05][i]`, rounded to two decimals; a word that is clearly easier or harder than its position may override with an explicit value in 0.05-0.95. The lint requires, per unit, that the mean difficulty strictly increases from lesson 1 to lesson 6, lesson 1's mean is at most 0.40 and lesson 6's mean at least 0.70.

### Contractual word lists (60 per unit, in lesson order; 10 per lesson)

If the lint reports a duplicate headword (or a word cannot be defended for its slot), replace it with another academic word of the same difficulty from the same domain and note the substitution in the report; never leave a duplicate.

**Health & Medicine (16):** L1 diagnose, symptom, disease, treatment, patient, surgery, infection, therapy, recovery, dose · L2 chronic, acute, vaccine, immune, nutrition, obesity, epidemic, mortality, disorder, pharmaceutical · L3 clinical, prescribe, allergy, genetic, hygiene, pathogen, antibiotic, rehabilitation, transplant, dementia · L4 contagious, remission, cardiovascular, sedative, placebo, cognitive, prognosis, prevalence, sanitation, cardiac · L5 immunity, mutation, malignant, benign, autopsy, palliative, hereditary, resistance, susceptible, longevity · L6 detrimental, ameliorate, exacerbate, debilitating, alleviate, morbidity, epidemiology, pathology, virulent, holistic.

**Environment & Energy (17):** L1 pollution, climate, fossil, renewable, emission, habitat, species, waste, recycle, drought · L2 ecosystem, biodiversity, erosion, conservation, sustainable, greenhouse, atmosphere, extinction, contamination, wildlife · L3 solar, nuclear, turbine, fuel, electricity, grid, efficiency, ozone, deforestation, glacier · L4 carbon, mitigate, ecological, endangered, irrigation, landfill, pesticide, toxic, sewage, offset · L5 biomass, geothermal, watershed, fertiliser, hydroelectric, arid, precipitation, degradation, indigenous, biosphere · L6 depletion, finite, exploit, preservation, resilient, vulnerable, adverse, replenish, catastrophic, hazardous.

**Technology & Innovation (18):** L1 technology, device, network, software, internet, digital, online, robot, screen, invent · L2 innovation, automate, algorithm, database, encryption, platform, interface, virtual, wireless, prototype · L3 bandwidth, circuit, hardware, upgrade, compatible, obsolete, integrate, simulate, sensor, biometric · L4 disrupt, scalable, proprietary, patent, licence, breakthrough, pioneer, outsource, streamline, refine · L5 ubiquitous, redundant, intuitive, autonomous, malfunction, convergence, adaptive, sophisticated, unprecedented, seamless · L6 paradigm, proliferation, infrastructure, manipulate, surveillance, anonymous, scrutinise, leverage, trajectory, incorporate.

**Education & Learning (19):** L1 education, student, teacher, school, university, lecture, exam, degree, knowledge, skill · L2 curriculum, literacy, tuition, scholarship, graduate, diploma, tutor, seminar, academic, campus · L3 pedagogy, syllabus, plagiarism, thesis, dissertation, postgraduate, undergraduate, enrolment, attendance, assignment · L4 comprehension, retention, motivation, feedback, discipline, aptitude, vocational, mentor, competence, proficiency · L5 inclusive, remedial, bilingual, dropout, credential, accreditation, cohort, scaffold, differentiate, extracurricular · L6 rigorous, rote, didactic, erudite, intellectual, scholarly, enlighten, instil, nurture, inquisitive.

**History & Culture (20):** L1 history, ancient, empire, war, revolution, century, heritage, monument, museum, artefact · L2 civilisation, dynasty, colony, invasion, conquest, treaty, medieval, monarchy, archaeology, chronicle · L3 renaissance, reformation, feudal, industrial, migration, nationalism, ideology, propaganda, ritual, folklore · L4 pilgrimage, aristocracy, peasant, nomadic, settlement, expedition, exile, dominion, era, legacy · L5 tribute, decree, manuscript, patriarchal, hierarchy, regime, sovereign, pillage, siege, uprising · L6 antiquity, epoch, chronology, hegemony, assimilate, vestige, posterity, oppression, emancipation, legitimacy.

**Psychology & Behaviour (21):** L1 emotion, behaviour, personality, memory, stress, attitude, motive, anxiety, habit, reaction · L2 instinct, impulse, phobia, conscious, trauma, empathy, intelligence, temperament, mood, counselling · L3 bias, stereotype, conformity, obedience, aggression, dependence, deviant, inhibition, phenomenon, spontaneous · L4 subconscious, hypothesis, correlation, stimulus, reinforcement, conditioning, introvert, extrovert, compulsive, insight · L5 ambivalent, repress, suppress, cope, grief, obsession, delusion, paranoia, compassion, resentment · L6 predisposition, propensity, volition, complacency, pragmatic, rationalise, catharsis, altruism, narcissism, ethos.

**Politics & Governance (22):** L1 government, election, vote, parliament, president, minister, party, campaign, citizen, democracy · L2 candidate, coalition, opposition, majority, minority, referendum, ballot, mandate, sanction, diplomacy · L3 bureaucracy, federal, sovereignty, republic, autocracy, dictatorship, corruption, lobby, veto, amendment · L4 pluralism, incumbent, electorate, delegate, ambassador, embassy, protocol, alliance, summit, constituency · L5 austerity, subsidy, tariff, embargo, deficit, surplus, welfare, taxation, fiscal, allocate · L6 partisan, populism, jurisdiction, accountability, transparency, impartial, coercion, dissent, autonomy, intervene.

**Media & Communication (23):** L1 media, newspaper, broadcast, audience, headline, article, message, channel, advertise, publish · L2 journalism, editorial, correspondent, censorship, circulation, subscription, tabloid, documentary, commentary, bulletin · L3 rhetoric, persuade, slogan, narrative, discourse, jargon, dialect, idiom, eloquent, articulate · L4 credibility, exaggerate, misinformation, hoax, satire, parody, allegation, rumour, retract, disclose · L5 publicity, endorsement, sponsor, viral, outreach, moderator, syndicate, copyright, footage, screenplay · L6 connotation, semantics, subtext, euphemism, ambiguity, paraphrase, rhetorical, verbatim, lucid, succinct.

None of these 480 words appears in the existing 120 (approach, available, concept … distinct, normal), and none repeats across units.

### Running totals to assert after each task

Baseline today: 13 units, 82 lessons, 190 items (120 `vocabulary` + 32 `grammarPoint` + 38 `practiceSet`), 583 questions, 15 passages, package version 7.

| After task | units | lessons | items | `vocabulary` | `grammarPoint` | `practiceSet` | questions | passages | version |
|---|---|---|---|---|---|---|---|---|---|
| 2 (unit 13) | 14 | 92 | 200 | 120 | 42 | 38 | 643 | 15 | 8 |
| 4 (units 14-15) | 16 | 100 | 208 | 120 | 50 | 38 | 701 | 15 | 8 |
| 6 (units 16-17) | 18 | 112 | 328 | 240 | 50 | 38 | 701 | 15 | 8 |
| 8 (units 18-19) | 20 | 124 | 448 | 360 | 50 | 38 | 701 | 15 | 8 |
| 10 (units 20-21) | 22 | 136 | 568 | 480 | 50 | 38 | 701 | 15 | 8 |
| 12 (units 22-23) | 24 | 148 | 688 | 600 | 50 | 38 | 701 | 15 | 8 |

## Review procedure (shared by Tasks 3, 5, 7, 9, 11 and 13)

**Whoever reviews must not have authored the unit.** Under subagent-driven execution dispatch a fresh subagent per unit with no authoring context; give it this section, the unit's files and the Global Constraints.

1. **Read cold** (no exemplars, no scopes first). **Solve every question before looking at any key** (technique units). For vocabulary units, judge every entry on its own before reading the contractual list.
2. **Technique units — score every question** `ok` / `fix` / `replace` on: key correct; exactly one defensible option (argue every distractor into correctness); distractors plausible, not junk, similar length, **correct option not the longest**; the stem forces the taught step; `explanationTR` gives the reasoning and refutes at least two named distractors with correct letters; register and typography; key distribution; stem+key natural. **Cards:** every rule correct, English examples grammatical, `En sık düşülen tuzak:` paragraph present and real, no invented statistics, no claim about ÖSYM scoring, consistent with the other strategy cards, and every step the lesson's questions test appears in its own card.
3. **Vocabulary units — score every entry** `ok` / `fix` / `replace` on: `translationTR` correct for the academic sense (and complete for polysemy); `definition` correct, Turkish, not circular; three example sentences natural, grammatical, B2-C1, each using the headword (or a clear inflection) in the sense being taught; three collocations that really occur; `baseDifficulty` plausible for the word relative to its lesson; no word duplicated anywhere in the package; British spelling consistent with the existing bank.
4. **Fix at the source** under `content/yds-academic-vocab-1/`, never in derived JSON; keep ids, counts, orders; regenerate with the real Python and confirm both derived files changed.
5. **More than five `replace` in one unit** (technique) or **more than 6 entries** (vocabulary): stop, do not patch, report and re-open the authoring task.
6. Commit with the message shown in the task, push, confirm both CI workflows green, report counts and every defect with its resolution.

## Authoring helpers (scratchpad, never committed)

Create `<scratchpad>/exam_common.py` from the 7c plan if it does not exist (`Q`, `lesson`). Add `<scratchpad>/tech_common.py`:

```python
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from exam_common import Q

ROOT = "C:/Users/niino/Desktop/ENGLISH/.worktrees/learning-engine/content/yds-academic-vocab-1"


def tech_lesson(unit_dir, slug, title, headword, rank, definition, explanation, minutes, skill, kind, questions):
    """questions: list of Q(...) dicts built with exam_common.Q (passage_id None)."""
    lid = f"yds-tech-{slug}"
    assert "En sık düşülen tuzak:" in explanation, slug
    doc = {"id": lid, "estimatedDurationMinutes": minutes, "title": title, "skill": skill, "items": [{
        "id": f"yds-tech-card-{slug}", "type": "grammarPoint", "headword": headword, "frequencyRank": rank,
        "baseDifficulty": 0.5, "definition": definition, "exampleSentences": [], "translationTR": title,
        "collocations": [], "explanationTR": explanation}], "questions": []}
    for i, q in enumerate(questions):
        doc["questions"].append({"id": f"{lid}-q{i + 1:02d}", "kind": kind, "order": i, "prompt": q["prompt"],
                                 "options": q["options"], "correctIndex": q["correctIndex"],
                                 "explanationTR": q["explanationTR"], "passageID": None})
    out = os.path.join(ROOT, "tech", unit_dir)
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, f"{slug}.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")


OFFSETS = [-0.04, -0.03, -0.02, -0.01, 0.0, 0.01, 0.02, 0.03, 0.04, 0.05]


def vocab_unit(slug, theme, order, lessons):
    """lessons: 6 lists of 10 entries. Entry = dict(h, d, ex=[3], tr, col=[3], diff=None)."""
    assert len(lessons) == 6
    unit = {"id": f"yds-vocab2-unit-{slug}", "theme": theme, "order": order, "lessons": []}
    k = 0
    for n, entries in enumerate(lessons, start=1):
        assert len(entries) == 10, (slug, n, len(entries))
        items = []
        for i, e in enumerate(entries):
            assert len(e["ex"]) == 3 and len(e["col"]) == 3, e["h"]
            diff = e.get("diff") if e.get("diff") is not None else round(0.25 + 0.1 * (n - 1) + OFFSETS[i], 2)
            items.append({
                "id": f"yds-vocab2-item-{e['h']}", "type": "vocabulary", "headword": e["h"],
                "frequencyRank": 100 + (order - 16) * 60 + k, "baseDifficulty": diff,
                "definition": e["d"], "exampleSentences": e["ex"], "translationTR": e["tr"], "collocations": e["col"],
            })
            k += 1
        unit["lessons"].append({"id": f"yds-vocab2-lesson-{slug}-{n}", "order": n - 1,
                                "estimatedDurationMinutes": 5, "items": items})
    os.makedirs(os.path.join(ROOT, "vocab2"), exist_ok=True)
    with open(os.path.join(ROOT, "vocab2", f"{slug}.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(unit, f, ensure_ascii=False, indent=2)
        f.write("\n")
```

Each authoring task writes a `gen_<name>.py` that imports these helpers.

**Vocabulary entry exemplar (the style bar):**

```python
dict(h="diagnose",
     d="Bir hastalığın ya da sorunun ne olduğunu belirtilere ve muayeneye bakarak saptamak.",
     ex=["Doctors diagnosed the condition as a rare form of anaemia.",
         "The disease is often diagnosed too late for treatment to be effective.",
         "It took specialists several months to diagnose the cause of her symptoms."],
     tr="teşhis etmek, tanı koymak",
     col=["diagnose a condition", "be diagnosed with", "correctly diagnose"])
```

---

## Task 1: `strategy` kind, assembly tables and the technique and vocabulary lint

**Files:**
- Modify: `LearningEngine/Sources/LearningEngine/Models/Question.swift`
- Modify: `scripts/assemble-content.py`
- Test: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`
- Verify unchanged: both derived JSON files

**Interfaces:**
- Produces: `QuestionKind.strategy`; in the script `TECH_DIR`, `TECH_UNITS` (empty), `TECH_LESSON_SHAPE`, `load_tech_units()`, `validate_tech_lesson()`, `VOCAB2_DIR`, `VOCAB2_FILES` (empty), `load_vocab2_units()`, `validate_vocab2_lesson()`, `validate_vocab2_unit()` and the package-wide headword-uniqueness check. With both tables empty the derived JSON stays **byte-identical**.

- [ ] **Step 1: Add the kind** — in `Question.swift` replace the second line of the enum body with `case paragraphCompletion, irrelevantSentence, dialogueCompletion, restatement, strategy`.

- [ ] **Step 2: Importer test** — in `ContentImporterTests.swift`, extend `test_importPackage_acceptsEveryExamQuestionKind` (find it by name) by adding `"strategy"` to its list of kinds (rename the test to `test_importPackage_acceptsEveryExtendedQuestionKind` and keep its body).

- [ ] **Step 3: Script — constants, kinds, tables.** In `scripts/assemble-content.py`: add `"strategy"` to `QUESTION_KINDS`; after the `ROMAN = ...` line add:

```python
TECH_DIR = os.path.join(REPO_ROOT, "content", "yds-academic-vocab-1", "tech")
# Slice 7d technique units (orders 13-15). Same contract as GRAMMAR_UNITS.
TECH_UNITS = []
TECH_LESSON_ID_PREFIX = "yds-tech-"
# slug -> (question kind, lesson skill, exact question count, exact minutes)
TECH_LESSON_SHAPE = {
    "reading": ("strategy", "reading", 6, 7), "cloze": ("strategy", "reading", 6, 7),
    "sentence": ("strategy", "grammar", 6, 7), "translation": ("strategy", "reading", 6, 7),
    "paragraph": ("strategy", "reading", 6, 7), "irrelevant": ("strategy", "reading", 6, 7),
    "dialogue": ("strategy", "grammar", 6, 7), "restatement": ("strategy", "reading", 6, 7),
    "vocabulary-questions": ("strategy", "reading", 6, 7), "grammar-questions": ("strategy", "grammar", 6, 7),
    "time-allocation": ("strategy", "reading", 6, 7), "elimination": ("strategy", "reading", 6, 7),
    "exam-day": ("strategy", "reading", 6, 7),
    "prefixes": ("grammar", "grammar", 8, 9), "suffixes": ("grammar", "grammar", 8, 9),
    "context-clues": ("strategy", "reading", 8, 9), "synonyms-collocations": ("strategy", "reading", 8, 9),
    "memorisation": ("strategy", "reading", 8, 9),
}
TECH_CARD_TRAP_PHRASE = "En sık düşülen tuzak:"

VOCAB2_DIR = os.path.join(REPO_ROOT, "content", "yds-academic-vocab-1", "vocab2")
# Slice 7d vocabulary units (orders 16-23): one unit document per file, in unit order.
VOCAB2_FILES = []
VOCAB2_LESSON_ID_PREFIX = "yds-vocab2-lesson-"
VOCAB2_LESSON_ID_RE = re.compile(r"^yds-vocab2-lesson-([a-z]+(?:-[a-z]+)*)-([1-6])$")
VOCAB2_HEADWORD_RE = re.compile(r"^[a-z]+(?:-[a-z]+)*$")
VOCAB2_ITEM_KEYS = {
    "id", "type", "headword", "frequencyRank", "baseDifficulty", "definition",
    "exampleSentences", "translationTR", "collocations",
}
```

- [ ] **Step 4: Script — loaders.** Add after `load_exam_units()`:

```python
def load_tech_units():
    """Builds the Slice 7d technique units from TECH_UNITS (list position = lesson order)."""
    units = []
    for unit_spec in TECH_UNITS:
        lessons = []
        for order, filename in enumerate(unit_spec["files"]):
            with open(os.path.join(TECH_DIR, filename), "r", encoding="utf-8") as f:
                lesson = json.load(f)
            if not lesson["id"].startswith(TECH_LESSON_ID_PREFIX):
                raise ValueError(f"technique lesson {lesson['id']} (from {filename}) must start with {TECH_LESSON_ID_PREFIX!r}")
            lesson = dict(lesson)
            lesson["order"] = order
            lessons.append(lesson)
        units.append({"id": unit_spec["id"], "theme": unit_spec["theme"], "order": unit_spec["order"], "lessons": lessons})
    return units


def load_vocab2_units():
    """Loads the Slice 7d vocabulary unit documents from VOCAB2_FILES."""
    units = []
    for filename in VOCAB2_FILES:
        with open(os.path.join(VOCAB2_DIR, filename), "r", encoding="utf-8") as f:
            units.append(json.load(f))
    return units
```

and change the units line in `assemble()` to

```python
    units = (attach_practice_lessons(load_units()) + load_grammar_units() + load_exam_units()
             + load_tech_units() + load_vocab2_units())
```

- [ ] **Step 5: Script — lint.** Add after `validate_exam_lesson()`:

```python
def validate_tech_lesson(lesson):
    """Shape rules for Slice 7d technique lessons, keyed off the lesson id prefix."""
    lesson_id = lesson["id"]
    slug = lesson_id[len(TECH_LESSON_ID_PREFIX):]
    if slug not in TECH_LESSON_SHAPE:
        raise ValueError(f"technique lesson id {lesson_id!r} has unknown slug {slug!r}")
    kind, skill, expected_questions, expected_minutes = TECH_LESSON_SHAPE[slug]
    if lesson["skill"] != skill:
        raise ValueError(f"technique lesson {lesson_id} must have skill {skill!r}, found {lesson['skill']!r}")
    if lesson["estimatedDurationMinutes"] != expected_minutes:
        raise ValueError(f"technique lesson {lesson_id} must have estimatedDurationMinutes {expected_minutes}")
    if "passage" in lesson:
        raise ValueError(f"technique lesson {lesson_id} must not carry a passage")
    if len(lesson["items"]) != 1 or lesson["items"][0]["type"] != "grammarPoint":
        raise ValueError(f"technique lesson {lesson_id} must own exactly one grammarPoint item")
    card = lesson["items"][0]
    if card["id"] != f"yds-tech-card-{slug}":
        raise ValueError(f"technique lesson {lesson_id}: card id {card['id']!r} must be 'yds-tech-card-{slug}'")
    if TECH_CARD_TRAP_PHRASE not in card.get("explanationTR", ""):
        raise ValueError(f"technique lesson {lesson_id}: card explanation must contain {TECH_CARD_TRAP_PHRASE!r}")
    questions = lesson.get("questions", [])
    if len(questions) != expected_questions:
        raise ValueError(f"technique lesson {lesson_id} must have exactly {expected_questions} questions, found {len(questions)}")
    for index, question in enumerate(sorted(questions, key=lambda q: q["order"])):
        qid = question["id"]
        if question["kind"] != kind:
            raise ValueError(f"question {qid} in {lesson_id} must have kind {kind!r}, found {question['kind']!r}")
        if question["order"] != index:
            raise ValueError(f"lesson {lesson_id} question orders must be 0..{expected_questions - 1} with no gaps")
        if qid != f"{lesson_id}-q{index + 1:02d}":
            raise ValueError(f"question at order {index} in {lesson_id} must be named {lesson_id}-q{index + 1:02d}")
        if len(set(question["options"])) != 5:
            raise ValueError(f"question {qid} has duplicate options")
        if question.get("passageID") is not None:
            raise ValueError(f"question {qid} must have passageID null")


def _vocab2_stem(headword):
    return headword[:max(3, len(headword) - 3)]


def validate_vocab2_lesson(lesson):
    """Shape rules for Slice 7d vocabulary lessons, keyed off the lesson id prefix."""
    lesson_id = lesson["id"]
    if VOCAB2_LESSON_ID_RE.match(lesson_id) is None:
        raise ValueError(f"vocabulary lesson id {lesson_id!r} must look like yds-vocab2-lesson-<slug>-<1..6>")
    if lesson["estimatedDurationMinutes"] != 5:
        raise ValueError(f"vocabulary lesson {lesson_id} must have estimatedDurationMinutes 5")
    if lesson["skill"] != "vocabulary":
        raise ValueError(f"vocabulary lesson {lesson_id} must have skill 'vocabulary'")
    items = lesson["items"]
    if len(items) != 10:
        raise ValueError(f"vocabulary lesson {lesson_id} must have exactly 10 items, found {len(items)}")
    for item in items:
        headword = item["headword"]
        iid = item["id"]
        if set(item) != VOCAB2_ITEM_KEYS:
            raise ValueError(f"item {iid} must have exactly the keys {sorted(VOCAB2_ITEM_KEYS)}")
        if item["type"] != "vocabulary":
            raise ValueError(f"item {iid} must have type 'vocabulary'")
        if VOCAB2_HEADWORD_RE.match(headword) is None:
            raise ValueError(f"item {iid}: headword {headword!r} must be lowercase ASCII letters and hyphens")
        if iid != f"yds-vocab2-item-{headword}":
            raise ValueError(f"item id {iid!r} must be 'yds-vocab2-item-{headword}'")
        if not isinstance(item["frequencyRank"], int) or item["frequencyRank"] < 1:
            raise ValueError(f"item {iid}: frequencyRank must be a positive integer")
        if not 0.05 <= item["baseDifficulty"] <= 0.95:
            raise ValueError(f"item {iid}: baseDifficulty must be within 0.05-0.95")
        definition = item["definition"].strip()
        if not definition.endswith(".") or len(definition) < 15:
            raise ValueError(f"item {iid}: definition must be a Turkish sentence ending with a full stop")
        if not item["translationTR"].strip():
            raise ValueError(f"item {iid}: empty translationTR")
        stem = _vocab2_stem(headword)
        for label, values in (("exampleSentences", item["exampleSentences"]), ("collocations", item["collocations"])):
            if len(values) != 3 or any(not v.strip() for v in values):
                raise ValueError(f"item {iid}: {label} must hold exactly 3 non-empty strings")
            for value in values:
                if stem not in value.lower():
                    raise ValueError(f"item {iid}: {label} entry {value!r} must contain {stem!r}")


def validate_vocab2_unit(unit):
    """Per-unit rules: six lessons with a strictly rising mean difficulty."""
    lessons = sorted(unit["lessons"], key=lambda l: l["order"])
    if len(lessons) != 6:
        raise ValueError(f"vocabulary unit {unit['id']} must have exactly 6 lessons, found {len(lessons)}")
    means = [sum(i["baseDifficulty"] for i in l["items"]) / len(l["items"]) for l in lessons]
    if any(b <= a for a, b in zip(means, means[1:])):
        raise ValueError(f"vocabulary unit {unit['id']}: mean difficulty must rise across lessons, found {[round(m, 3) for m in means]}")
    if means[0] > 0.40 or means[-1] < 0.70:
        raise ValueError(f"vocabulary unit {unit['id']}: lesson 1 mean must be <= 0.40 and lesson 6 mean >= 0.70")
```

- [ ] **Step 6: Script — hook the lint.** In `validate_content`, add `headwords = set()` next to the other `set()` declarations at the top; inside the per-lesson loop, after the item-id duplicate check (`item_ids.add(item["id"])`), add:

```python
                if item["type"] == "vocabulary":
                    key = item["headword"].strip().lower()
                    if key in headwords:
                        raise ValueError(f"duplicate vocabulary headword {item['headword']!r} (lesson {lesson_id})")
                    headwords.add(key)
```

and below the existing `validate_exam_lesson` hook add

```python
            if lesson_id.startswith(TECH_LESSON_ID_PREFIX):
                validate_tech_lesson(lesson)
            if lesson_id.startswith(VOCAB2_LESSON_ID_PREFIX):
                validate_vocab2_lesson(lesson)
```

and, right after the `for unit in package["units"]:` line's duplicate-unit-id check, add `if unit["id"].startswith("yds-vocab2-unit-"): validate_vocab2_unit(unit)`.

- [ ] **Step 7: Lint self-check (scratchpad script `lint_check_7d.py`, never committed).** It imports the module like the 7c `lint_check_exam.py`, builds minimal valid dicts and asserts acceptance plus rejection of: unknown tech slug, wrong tech skill/minutes/question count/kind, missing trap phrase, missing/extra passage, duplicate options, vocabulary lesson with 9 items, headword with uppercase or digit, wrong item id, missing key or extra key, definition without a full stop, an example sentence not containing the stem, 2 collocations, difficulty out of range, a unit whose mean difficulty does not rise, and a duplicate headword across two lessons through `validate_content`. Every check prints `PASS`; finish with `ALL CHECKS PASSED`. Run it with the real interpreter.

- [ ] **Step 8: Confirm the derived JSON is unchanged** — run the assembly script; `git status --short` must show only `Question.swift`, the script and `ContentImporterTests.swift`.

- [ ] **Step 9: Commit, push, confirm both CI workflows green**

```bash
git add LearningEngine scripts/assemble-content.py
git commit -m "$(cat <<'EOF'
Add the strategy question kind, the technique and vocabulary tables and their lint for Slice 7d

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

## Task 2: Unit "Sınav soru tipi stratejileri" — 10 technique lessons, 60 questions, package version 8

**Files:**
- Create: `content/yds-academic-vocab-1/tech/question-strategies/<slug>.json` for the ten slugs of unit 13 (contract table)
- Modify: `scripts/assemble-content.py` (`TECH_UNITS` first entry, `PACKAGE_VERSION` 7 → 8)
- Regenerate: both derived JSON files
- Modify: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`, `App/Tests/EnglishAppTests/RealContentSeedingTests.swift`, `App/Tests/EnglishAppTests/CoursePathViewModelTests.swift`

**Interfaces:**
- Consumes: Task 1's lint and tables. Produces: version **8**; unit `yds-tech-unit-question-strategies` at order 13; the test `test_bundledPackage_techniqueUnits_areStructurallySound()` that Task 4 extends.

### Card and question scope per lesson (contractual)

Each card (`explanationTR`): Turkish `•` blocks separated by `\n\n`, at least one English example per block, and a final `En sık düşülen tuzak:` paragraph. Each lesson's six questions apply the technique: short English exam items (a sentence, a mini-paragraph, a stem) where the taught step decides the answer, or Turkish knowledge/scenario questions about the step. Distribute keys per the constraint. **Never state ÖSYM scoring or penalty rules.**

- **reading:** read the question stems first; skim for structure (topic sentences); locate the relevant lines before choosing; check every option against the text; discard "true but not stated" and absolute words (`always`, `never`, `only`, `all`); vocabulary-in-context: read the whole sentence, not the word alone; inference vs stated fact. Questions: which step first; locate-then-verify on a mini-paragraph; an absolute-word trap; a true-but-not-stated trap; vocabulary in context; inference vs detail.
- **cloze:** read the whole sentence, then the sentences before and after; classify the blank (connector, preposition, relative pronoun, verb form, quantifier, vocabulary); test each option in the sentence; check both sides of the blank; collocations and fixed phrases. Questions on classifying a blank, connector logic, preposition-after-noun collocation, verb-form agreement, relative pronoun choice, vocabulary blank.
- **sentence:** find the logical relation the stem sets up (cause, contrast, condition, purpose, time); the completion must fit that relation and the grammar (tense, subject); eliminate options that repeat or contradict; check that stem + option is one natural sentence. Questions covering each relation and a tense-consistency trap.
- **translation:** find subject, verb, tense, negation, modality and every qualifier in the stem; compare each option piece by piece; each wrong option usually changes exactly one element; do not choose by vocabulary alone. Questions with Turkish/English pairs where the deciding element is tense, negation, voice, quantifier, a connector.
- **paragraph:** find the paragraph's main line; reference words (`this`, `these`, `however`) and what the sentence before/after demands; the missing sentence must connect both neighbours; reject topic shifts and contradictions. Questions on opening, linking and closing positions.
- **irrelevant:** find the topic sentence and the chain (pronouns, connectors); the odd sentence breaks the chain or shifts focus; a sentence sharing vocabulary can still be off-topic. Questions with five-sentence mini-paragraphs (options I-V are numerals, so build each with the numeral options as in 7c).
- **dialogue:** identify the speech act (request, apology, refusal, suggestion); the missing line must answer the previous line AND lead into the next; register and tone; reject options that ignore the previous speaker. Questions with short two-speaker exchanges.
- **restatement:** paraphrase means same meaning, not same words; check tense, condition (`unless` = `if not`), quantifiers, modality, cause and effect direction; reject options that reverse a relation. Questions with conditionals, quantifiers, inversion and causal pairs.
- **vocabulary-questions:** use context clues (contrast, example, definition signals); collocations; word form (part of speech required by the blank); near-synonym traps. Questions on each.
- **grammar-questions:** identify the tested point first (tense marker, preposition, relative clause, conditional, modal, agreement); use time markers; check agreement and parallelism. Questions on each.
- **time-allocation:** average time per question from the total exam length stated in the guide (say "sınav süresini kılavuzdan öğren"); do quick question types first and mark long ones to return to; do not spend more than a set time on one item; keep a few minutes for the answer sheet. Questions are Turkish scenarios (an item takes too long; two minutes remain; a reading passage is long) with a defensible best behaviour.
- **elimination:** eliminate options that are wrong for a nameable reason; compare the last two options against the stem; guess only after eliminating; never change an answer without a concrete reason. Scenario questions with a short English item where two options survive.
- **exam-day:** sleep and food, documents, arriving early, reading instructions, marking the answer sheet carefully, staying calm after a hard passage; do not compare answers during the exam. Turkish scenario questions.

### Steps

- [ ] **Step 1: Author the ten lesson files** with `tech_lesson(...)` (`unit_dir="question-strategies"`, titles/headwords/ranks/minutes/skills/kinds per the contract table; rank 4000 + table position; headword e.g. `Strategy: Reading Questions`; definition e.g. `"Okuma sorularını adım adım çözme tekniği."`). Six questions per lesson, keys planned so each key appears at most twice and never three in a row (for example `[2, 0, 4, 1, 3, 0]`).
- [ ] **Step 2: Register the unit and bump the version.** Replace `TECH_UNITS = []` with:

```python
TECH_UNITS = [
    {
        "id": "yds-tech-unit-question-strategies",
        "theme": "Sınav soru tipi stratejileri",
        "order": 13,
        "files": [
            "question-strategies/reading.json", "question-strategies/cloze.json",
            "question-strategies/sentence.json", "question-strategies/translation.json",
            "question-strategies/paragraph.json", "question-strategies/irrelevant.json",
            "question-strategies/dialogue.json", "question-strategies/restatement.json",
            "question-strategies/vocabulary-questions.json", "question-strategies/grammar-questions.json",
        ],
    },
]
```

and set the version block's end to:

```python
# 8: Slice 7d adds the study-technique and second vocabulary units (orders
# 13-23). Bumping this makes installed apps re-import the package; every
# existing id is unchanged, so FSRS history survives the reseed.
PACKAGE_VERSION = 8
```

- [ ] **Step 3: Regenerate** with the real Python and confirm both derived files changed.
- [ ] **Step 4: Update the tests.**
  - `ContentImporterTests.swift` (`test_importPackage_realYDSPackage_importsEveryUnitItemAndQuestion`): `package.version` → `8`; `package.units.count` → `14`; both item counts → `200`; `.grammarPoint` → `42`; both question counts → `643`. Leave `.vocabulary` 120 and `.practiceSet` 38.
  - `RealContentSeedingTests.swift`: `package.units.count` → `14`; both `allItems.count` → `200`; `package.version` → `8`; questions → `643`. In `test_bundledPackage_examUnits_areStructurallySound` replace `let examUnits = Array(units.dropFirst(9))` with `let examUnits = Array(units[9..<13])`. Add this test (Task 4 extends its three lists):

```swift
    /// Structure gate for the Slice 7d technique units, read from the shipped app resource.
    func test_bundledPackage_techniqueUnits_areStructurallySound() throws {
        guard let url = Bundle.main.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            XCTFail("YDSAcademicVocabulary1.json not found in the app bundle")
            return
        }
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: try Data(contentsOf: url), into: context)
        try context.save()

        let units = package.units.sorted { $0.order < $1.order }
        XCTAssertEqual(units.map(\.order), Array(0..<units.count), "unit orders must be contiguous from 0")
        let techUnits = Array(units[13..<14])
        XCTAssertEqual(techUnits.map(\.id), ["yds-tech-unit-question-strategies"])
        XCTAssertEqual(techUnits.map(\.theme), ["Sınav soru tipi stratejileri"])
        XCTAssertEqual(techUnits.map(\.order), [13])
        XCTAssertEqual(
            units[13].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-tech-reading", "yds-tech-cloze", "yds-tech-sentence", "yds-tech-translation",
                "yds-tech-paragraph", "yds-tech-irrelevant", "yds-tech-dialogue", "yds-tech-restatement",
                "yds-tech-vocabulary-questions", "yds-tech-grammar-questions",
            ]
        )
        for lesson in techUnits.flatMap(\.lessons) {
            let slug = String(lesson.id.dropFirst("yds-tech-".count))
            XCTAssertEqual(lesson.items.count, 1, "\(lesson.id) must own exactly one card")
            let card = try XCTUnwrap(lesson.items.first)
            XCTAssertEqual(card.type, .grammarPoint, lesson.id)
            XCTAssertEqual(card.id, "yds-tech-card-" + slug, lesson.id)
            XCTAssertTrue((card.content?.explanationTR ?? "").contains("En sık düşülen tuzak:"), lesson.id)
            XCTAssertNil(lesson.passage, lesson.id)
            XCTAssertEqual(lesson.questions.count, 6, lesson.id)
            XCTAssertEqual(lesson.estimatedDurationMinutes, 7, lesson.id)
            for question in lesson.questions {
                XCTAssertEqual(question.kind, .strategy, question.id)
                XCTAssertEqual(question.options.count, 5, question.id)
                XCTAssertTrue((0...4).contains(question.correctIndex), question.id)
                XCTAssertFalse(question.explanationTR.isEmpty, question.id)
                XCTAssertNil(question.passage, question.id)
            }
        }
    }
```

  - `CoursePathViewModelTests.swift`: `sections.count` → `14`; `sections.last?.unitID` → `"yds-tech-unit-question-strategies"`; `sections.last?.tasks.count` → `10`.
- [ ] **Step 5: Commit, push, confirm both CI workflows green**

```bash
git add content scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests App/Tests
git commit -m "$(cat <<'EOF'
Add the Sınav soru tipi stratejileri technique unit with 60 questions, package version 8

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

## Task 3: Independent review — unit "Sınav soru tipi stratejileri"

**Files:** modify only where defects are found: the ten files under `content/yds-academic-vocab-1/tech/question-strategies/`, then regenerate both derived JSON files.

- [ ] **Step 1: Run the shared "Review procedure" (technique-unit rules)** over the ten lessons. Extra checks: every card step is correct exam advice and is what the lesson's questions test; the ten cards are mutually consistent (for example the same advice about absolute words everywhere); no claim about ÖSYM scoring or invented statistics; Turkish is natural.
- [ ] **Step 2: Commit any fixes (skip if none)** with the message `Apply content review fixes to the Sınav soru tipi stratejileri technique unit` (same trailer and heredoc form as Task 2).
- [ ] **Step 3: Push, confirm both CI workflows green**, record the verdict.

---

## Task 4: Units "Sınav yönetimi ve zaman" and "Kelime öğrenme teknikleri" — 8 technique lessons, 58 questions

**Files:**
- Create: `content/yds-academic-vocab-1/tech/exam-management/{time-allocation,elimination,exam-day}.json`, `content/yds-academic-vocab-1/tech/vocabulary-skills/{prefixes,suffixes,context-clues,synonyms-collocations,memorisation}.json`
- Modify: `scripts/assemble-content.py` (`TECH_UNITS` second and third entries), the three test files
- Regenerate: both derived JSON files

**Interfaces:** Consumes Task 1's lint and Task 2's test. Produces units at orders 14 and 15.

### Scope (contractual)

- **time-allocation, elimination, exam-day:** as in Task 2's scope list (six Turkish scenario/knowledge questions each).
- **prefixes** (8 questions, kind `grammar`): un-, dis-, mis-, re-, pre-, post-, inter-, sub-, anti-, co-, over-, under-, in-/im-/il-/ir- (negation vs "in/into"); the questions ask the meaning of a prefix in a word, choose the word that a given prefix builds, or complete a sentence with the right prefixed form (`misinterpret`, `overestimate`, `inaccurate` vs `irrelevant`).
- **suffixes** (8 questions, kind `grammar`): noun (-ment, -ness, -ity, -tion), verb (-ize/-ise, -ify, -en), adjective (-al, -ous, -ive, -able, -ful, -less), adverb (-ly); the questions ask which word form fits the blank (part of speech required), or which suffix changes the word class.
- **context-clues** (8, `strategy`): contrast, example, definition and cause/effect signals to guess an unknown word; short English sentences with a nonsense-free rare word whose meaning the context gives.
- **synonyms-collocations** (8, `strategy`): near-synonyms are not interchangeable (`make a decision` / `take a decision`, `strong` vs `powerful`), learn words in collocations, choose the collocate.
- **memorisation** (8, `strategy`): spaced repetition, active recall, learning word families, writing your own sentences; Turkish scenario/knowledge questions about which study habit is more effective and why (no invented statistics).

Cards follow the Task 2 conventions (`•` blocks, English examples, `En sık düşülen tuzak:`).

### Steps

- [ ] **Step 1: Author the eight files** (`unit_dir` `exam-management` and `vocabulary-skills`); ranks 4010-4017 per the contract table order; eight-question lessons use keys such as `[1, 3, 0, 4, 2, 1, 3, 0]`.
- [ ] **Step 2: Register the units.** Append to `TECH_UNITS`:

```python
    {
        "id": "yds-tech-unit-exam-management",
        "theme": "Sınav yönetimi ve zaman",
        "order": 14,
        "files": [
            "exam-management/time-allocation.json", "exam-management/elimination.json",
            "exam-management/exam-day.json",
        ],
    },
    {
        "id": "yds-tech-unit-vocabulary-skills",
        "theme": "Kelime öğrenme teknikleri",
        "order": 15,
        "files": [
            "vocabulary-skills/prefixes.json", "vocabulary-skills/suffixes.json",
            "vocabulary-skills/context-clues.json", "vocabulary-skills/synonyms-collocations.json",
            "vocabulary-skills/memorisation.json",
        ],
    },
```

- [ ] **Step 3: Regenerate** and confirm both derived files changed.
- [ ] **Step 4: Update the tests.**
  - `ContentImporterTests.swift`: `package.units.count` → `16`; both item counts → `208`; `.grammarPoint` → `50`; both question counts → `701`.
  - `RealContentSeedingTests.swift`: `package.units.count` → `16`; both `allItems.count` → `208`; questions → `701`. In the technique structure test replace the head with `let techUnits = Array(units[13..<16])`, the three unit lists with

```swift
        XCTAssertEqual(
            techUnits.map(\.id),
            ["yds-tech-unit-question-strategies", "yds-tech-unit-exam-management", "yds-tech-unit-vocabulary-skills"]
        )
        XCTAssertEqual(
            techUnits.map(\.theme),
            ["Sınav soru tipi stratejileri", "Sınav yönetimi ve zaman", "Kelime öğrenme teknikleri"]
        )
        XCTAssertEqual(techUnits.map(\.order), [13, 14, 15])
```

  add after the `units[13]` lesson-id assertion:

```swift
        XCTAssertEqual(
            units[14].lessons.sorted { $0.order < $1.order }.map(\.id),
            ["yds-tech-time-allocation", "yds-tech-elimination", "yds-tech-exam-day"]
        )
        XCTAssertEqual(
            units[15].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-tech-prefixes", "yds-tech-suffixes", "yds-tech-context-clues",
                "yds-tech-synonyms-collocations", "yds-tech-memorisation",
            ]
        )
```

  and make the per-lesson checks slug-aware: replace the fixed `6` questions, `7` minutes and `.strategy` kind assertions with a lookup in a private table

```swift
    private static let techShapes: [String: (kind: QuestionKind, questions: Int, minutes: Int)] = [
        "prefixes": (.grammar, 8, 9), "suffixes": (.grammar, 8, 9),
        "context-clues": (.strategy, 8, 9), "synonyms-collocations": (.strategy, 8, 9),
        "memorisation": (.strategy, 8, 9),
    ]
```

  using `let shape = Self.techShapes[slug] ?? (.strategy, 6, 7)` for `lesson.questions.count`, `lesson.estimatedDurationMinutes` and `question.kind`.
  - `CoursePathViewModelTests.swift`: `sections.count` → `16`; `sections.last?.unitID` → `"yds-tech-unit-vocabulary-skills"`; `sections.last?.tasks.count` → `5`.
- [ ] **Step 5: Commit, push, confirm both CI workflows green**

```bash
git add content scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests App/Tests
git commit -m "$(cat <<'EOF'
Add the Sınav yönetimi ve zaman and Kelime öğrenme teknikleri technique units with 58 questions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

## Task 5: Independent review — units 14 and 15

**Files:** modify only where defects are found: the eight files under `tech/exam-management/` and `tech/vocabulary-skills/`, then regenerate both derived JSON files.

- [ ] **Step 1: Run the shared "Review procedure" (technique-unit rules)**. Extra checks: word-formation questions (prefixes/suffixes) test one defensible form each and the English words are real and correctly built; exam-management cards contain no claim about ÖSYM scoring, timing figures or penalties; memorisation advice makes no invented statistic; scenario questions have exactly one best behaviour.
- [ ] **Step 2: Commit any fixes (skip if none)** with the message `Apply content review fixes to the exam management and vocabulary skills technique units`.
- [ ] **Step 3: Push, confirm both CI workflows green**, record the verdict.

---

## Tasks 6, 8, 10, 12: Vocabulary units (two units, 120 words, per task)

Each of these tasks has the same structure. The unit pair, files, orders and expected totals:

| Task | Units (order) | Files to create | After this task |
|---|---|---|---|
| 6 | Health & Medicine (16), Environment & Energy (17) | `vocab2/health-medicine.json`, `vocab2/environment-energy.json` | units 18, lessons 112, items 328, vocabulary 240 |
| 8 | Technology & Innovation (18), Education & Learning (19) | `vocab2/technology-innovation.json`, `vocab2/education-learning.json` | units 20, lessons 124, items 448, vocabulary 360 |
| 10 | History & Culture (20), Psychology & Behaviour (21) | `vocab2/history-culture.json`, `vocab2/psychology-behaviour.json` | units 22, lessons 136, items 568, vocabulary 480 |
| 12 | Politics & Governance (22), Media & Communication (23) | `vocab2/politics-governance.json`, `vocab2/media-communication.json` | units 24, lessons 148, items 688, vocabulary 600 |

**Steps (identical for every one of these tasks):**

- [ ] **Step 1: Author the two unit files** with `vocab_unit(...)` from `tech_common.py`, using the contractual word lists above for that unit (10 words per lesson, in the listed order). For every word write: a Turkish `definition` (one sentence, ends with `.`, defines the word), three original B2-C1 example sentences in academic register that use the headword or a clear inflection (vary the sentence types; no sentence reused between words), the Turkish `translationTR` for the academic sense (with the extra senses the academic usage needs), and three real collocations. Keep British spelling consistent with the existing bank. Optionally override `diff` for a word that is clearly easier or harder than its position.
- [ ] **Step 2: Register the files** — append the two filenames to `VOCAB2_FILES` in unit order (for Task 6: `"health-medicine.json"`, `"environment-energy.json"`; later tasks append their two after the earlier ones).
- [ ] **Step 3: Regenerate** with the real Python; the lint must pass (it enforces item counts, keys, stems, difficulty rise and package-wide headword uniqueness); confirm both derived files changed and `scripts/__pycache__/` is deleted. If the lint reports a duplicate headword, substitute per the "Contractual word lists" rule.
- [ ] **Step 4: Update the tests.** Apply the "After this task" numbers from the table above to:
  - `ContentImporterTests.swift`: `package.units.count`; both item counts; `.vocabulary` count (currently `120`); leave `.grammarPoint` 50, `.practiceSet` 38, questions 701, version 8.
  - `RealContentSeedingTests.swift`: `package.units.count`; both `allItems.count`. **Task 6 also** adds this test (later tasks extend only its three lists):

```swift
    /// Structure gate for the Slice 7d vocabulary units, read from the shipped app resource.
    func test_bundledPackage_secondVocabularyUnits_areStructurallySound() throws {
        guard let url = Bundle.main.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            XCTFail("YDSAcademicVocabulary1.json not found in the app bundle")
            return
        }
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: try Data(contentsOf: url), into: context)
        try context.save()

        let units = package.units.sorted { $0.order < $1.order }
        XCTAssertEqual(units.map(\.order), Array(0..<units.count), "unit orders must be contiguous from 0")
        let vocabUnits = Array(units[16...])
        XCTAssertEqual(vocabUnits.map(\.id), ["yds-vocab2-unit-health-medicine", "yds-vocab2-unit-environment-energy"])
        XCTAssertEqual(vocabUnits.map(\.theme), ["Health & Medicine", "Environment & Energy"])
        XCTAssertEqual(vocabUnits.map(\.order), [16, 17])

        var seenHeadwords = Set<String>()
        for unit in vocabUnits {
            XCTAssertEqual(unit.lessons.count, 6, unit.id)
            let slug = String(unit.id.dropFirst("yds-vocab2-unit-".count))
            XCTAssertEqual(
                unit.lessons.sorted { $0.order < $1.order }.map(\.id),
                (1...6).map { "yds-vocab2-lesson-\(slug)-\($0)" }
            )
            for lesson in unit.lessons {
                XCTAssertEqual(lesson.skill, .vocabulary, lesson.id)
                XCTAssertEqual(lesson.estimatedDurationMinutes, 5, lesson.id)
                XCTAssertTrue(lesson.questions.isEmpty, lesson.id)
                XCTAssertEqual(lesson.items.count, 10, lesson.id)
                for item in lesson.items {
                    XCTAssertEqual(item.type, .vocabulary, item.id)
                    let content = try XCTUnwrap(item.content, item.id)
                    XCTAssertEqual(content.exampleSentences.count, 3, item.id)
                    XCTAssertEqual(content.collocations.count, 3, item.id)
                    XCTAssertFalse(content.translationTR.isEmpty, item.id)
                    XCTAssertTrue(seenHeadwords.insert(content.headword).inserted, "duplicate headword \(content.headword)")
                }
            }
        }
        XCTAssertEqual(seenHeadwords.count, vocabUnits.count * 60)
    }
```

  For Tasks 8, 10 and 12 extend the three lists (`vocabUnits.map(\.id)`, `.theme`, `.order`) with the new units in order (ids and themes from the unit table). Also add the new unit's lesson-count check already covered by the loop.
  - `CoursePathViewModelTests.swift`: `sections.count` → the units number from the table; `sections.last?.unitID` → the last unit id of the pair; `sections.last?.tasks.count` → `6`.
- [ ] **Step 5: Commit, push, confirm both CI workflows green**

```bash
git add content scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests App/Tests
git commit -m "$(cat <<'EOF'
Add the <first theme> and <second theme> vocabulary units with 120 words

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

(Replace the two theme names in the message with the pair's themes.)

**Note on the level test:** the level-test candidate pool is every vocabulary item of the active package, so each task grows it; no test pins the pool size (the only real-package word-count assertion is the `.vocabulary` count updated above). If a level-test test fails on the real package, do not weaken it: investigate whether a new item lacks a translation.

---

## Tasks 7, 9, 11, 13: Independent reviews of the vocabulary unit pairs

| Task | Review of |
|---|---|
| 7 | Health & Medicine, Environment & Energy |
| 9 | Technology & Innovation, Education & Learning |
| 11 | History & Culture, Psychology & Behaviour |
| 13 | Politics & Governance, Media & Communication |

- [ ] **Step 1: Dispatch one fresh reviewer per unit (two per task, may run in parallel)** and run the shared "Review procedure" (vocabulary-unit rules). Each reviewer checks all 60 entries of its unit. Extra checks: polysemous words (`patient`, `treatment`, `dose`, `channel`, `article`, `degree`, `discipline`, `resistance`, `party`, `era`, `bias`, `outreach`) have Turkish that fits the academic sense; false-friend risks (`sympathy`/`empathy`, `compassion`, `sensitive`, `actual`-type words) are handled; collocations really occur; example sentences are natural and each teaches the headword in one clear sense; difficulty is plausible relative to the lesson; British spelling.
- [ ] **Step 2: Commit any fixes (skip if none)** with the message `Apply content review fixes to the <first theme> and <second theme> vocabulary units`.
- [ ] **Step 3: Push, confirm both CI workflows green**, record the verdict per unit.

---

## Task 14: Whole-branch review and close

**Files:** modify only where defects are found; read-only: the script and the test files.

- [ ] **Step 1: Verify the whole package mechanically**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" - <<'PY'
import importlib.util, os
spec = importlib.util.spec_from_file_location("assemble", os.path.join("scripts", "assemble-content.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
pkg = mod.assemble()
lessons = [l for u in pkg["units"] for l in u["lessons"]]
questions = [q for l in lessons for q in l.get("questions", [])]
items = [i for l in lessons for i in l["items"]]
print("version", pkg["version"])
print("units", len(pkg["units"]), [u["order"] for u in pkg["units"]] == list(range(24)))
print("lessons", len(lessons))
print("items", len(items), "vocabulary", sum(1 for i in items if i["type"] == "vocabulary"),
      "grammarPoint", sum(1 for i in items if i["type"] == "grammarPoint"),
      "practiceSet", sum(1 for i in items if i["type"] == "practiceSet"))
print("questions", len(questions))
print("passages", sum(1 for l in lessons if "passage" in l))
prompts = {}
for q in questions:
    prompts.setdefault(q["prompt"].strip().lower(), []).append(q["id"])
dup = {p: ids for p, ids in prompts.items() if len(ids) > 1}
print("duplicate prompts:", dup if dup else "none")
words = [i["headword"].lower() for i in items if i["type"] == "vocabulary"]
print("distinct headwords", len(set(words)), "of", len(words))
PY
rm -rf scripts/__pycache__
```

Expected, exactly: `version 8`, `units 24 True`, `lessons 148`, `items 688 vocabulary 600 grammarPoint 50 practiceSet 38`, `questions 701`, `passages 15`, `duplicate prompts: none`, `distinct headwords 600 of 600`; `git status` clean.

- [ ] **Step 2: Cross-unit check by a fresh reviewer (not an author).** Draw 30 technique questions across the three technique units (at least ten from units 13, five from unit 14, ten from unit 15) and solve them cold; draw 60 vocabulary entries (at least seven per unit) and check translation, definition, examples and collocations cold. Also: read all 18 strategy cards end to end for advice stated inconsistently across cards or contradicting the explanations of the 7c exam lessons; check that no strategy question repeats a 7b/7c question idea with the same key; check `(A)`-`(E)` letters in every technique explanation programmatically; check technique keys are not systematically the longest option; check vocabulary Turkish for ASCII-substitute spellings. Any disagreement is a defect: fix at source, regenerate, note it. Two or more disagreements in one unit means that unit's review gate was not applied — re-open that unit's review task.
- [ ] **Step 3: Confirm the spec's acceptance criteria** one by one against the shipped package: the 11 new unit ids, themes and orders; technique lesson shapes; the 8 vocabulary units of 6 lessons × 10 words with 3 examples and 3 collocations each; no duplicate headword; version 8 with every pre-existing id unchanged; the free preview still exactly the first unit's 3 vocabulary + 7 practice lessons and every new unit locked (`test_dersYolu_previewUser_...` passes with only its counts and unit id changed); no access-policy, purchase-flow or AI-gate change (`git diff` of `App/Sources` shows no change from this slice).
- [ ] **Step 4: Commit any fixes (skip if none)** with the message `Apply whole-branch review fixes to the vocabulary and study techniques slice`.
- [ ] **Step 5: Final CI run** — both workflows green at the branch head.
- [ ] **Step 6: Record the known gaps and continue.** Add to the TestFlight checklist in `docs/store-setup.md`: a strategy lesson end to end (card, then questions), a vocabulary lesson from a new unit, and the level test after the pool grew (does placement feel right with harder words). Update `Desktop\ENGLISH_KALANLAR.txt`. Then start Slice 9 (AI study coach) with `superpowers:brainstorming`. Integration of the branch stays the user's decision.

---

## Self-review

**1. Spec coverage.**

| Spec requirement | Task |
|---|---|
| `strategy` kind, tables, technique lint, vocabulary lint, headword uniqueness, version 8 | 1, 2 |
| Unit 13: 10 strategy lessons, 60 questions | 2 (authoring), 3 (review) |
| Units 14-15: exam management and vocabulary skills, 58 questions | 4, 5 |
| 8 vocabulary units of 60 words, contractual word lists, difficulty spread | 6, 8, 10, 12 (authoring), 7, 9, 11, 13 (reviews) |
| Locked units, free preview unchanged | Preview test in every unit task; checked in 14 |
| Quality rules incl. no ÖSYM scoring claims, balanced option lengths | Global Constraints, review procedure |
| Totals and structure tests | Running-totals table; tests in 2, 4, 6, 8, 10, 12 |
| Known gaps (strategy lesson on device, level test pool) | Task 14 step 6 |

**2. Placeholder scan.** No "TBD"/"TODO"; every code step carries its code. The content tasks specify contracts, scopes, word lists and exemplars; the entries and questions themselves are authored to those contracts and verified by the lint and independent review, exactly as in 7b and 7c.

**3. Type consistency.** `TECH_UNITS`, `TECH_LESSON_SHAPE`, `VOCAB2_FILES`, `validate_tech_lesson`, `validate_vocab2_lesson`, `validate_vocab2_unit`, `load_tech_units`, `load_vocab2_units` are named identically everywhere. Ids follow the contracts (`yds-tech-<slug>`, `yds-tech-card-<slug>`, `yds-vocab2-*`). Running totals: units 14/16/18/20/22/24, lessons 92/100/112/124/136/148, items 200/208/328/448/568/688, vocabulary 120/120/240/360/480/600, `grammarPoint` 42/50, questions 643/701.
