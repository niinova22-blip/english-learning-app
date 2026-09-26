# Authoring lesson cards and Turkish explanations

Spec: `docs/superpowers/specs/2026-09-26-beginner-lessons-design.md`.
Library and lint: `scripts/overlay_lib.py` (read its docstring).

## Who reads this

A Turkish learner who may be starting from zero and **does not read English
well**. Every Turkish text must be understandable without any English
knowledge and without grammar jargon. Write as a friendly teacher talking to
one student: "sen" form, short sentences, everyday words.

- A grammar term is allowed only with a plain explanation the first time:
  "özne (cümlede işi yapan kişi ya da şey)".
- Compare with Turkish whenever it helps: "Türkçedeki -r eki gibi (gelirim)".
- English words inside Turkish text go in double quotes: "usually".
- Natural Turkish, never word-for-word translation. Turkish spelling with
  ç ğ ı İ ö ş ü, correct suffix apostrophes (it'ten, "drinks"e).
- English fields (`en`, examples' `en`, `wrong`, `right`, check prompt and
  options) contain no Turkish letters.

## Files

One file per lesson: `content/<package-id>/lessons/<lesson id>.json`.
Create or complete the skeletons first:

    python scripts/overlay_scaffold.py <package-id> <unit-id> [<unit-id> ...]

It pre-fills every question's current explanation as `en` and leaves `tr`,
`passageTR` and missing `wordMeanings` empty. Fill every empty string. Do
not change `en` explanations, ids or anything outside your own lesson files.

Validate without writing app resources (run after every file):

    python scripts/assemble-package.py <package-id> --lint     # Business, Everyday
    python scripts/assemble-content.py --lint                  # YDS

Do not run the assemblers without `--lint` and do not commit — the
coordinator regenerates resources and commits.

## 1. Lesson cards (`lessonCards`, grammar lessons)

Golden example — copy its style exactly:
`content/everyday-english-1/lessons/day-u01-grammar.json`.

Base the cards on the grammar item's current explanation and on what the
lesson's questions actually test (read them — every rule a question needs
must be on a card).

- One idea per topic. Split big topics (e.g. several tenses) into several
  topics, 1-4 topics per lesson.
- `title`: short, both languages.
- `purpose`: at most 2 short sentences — when/why we use it; the Turkish side
  with a Turkish comparison when one exists.
- `pattern`: the English formula as ordered parts; `role` is one of subject,
  verb, aux, object, other (it only colors the chip). At least 2 parts.
- `patternNote` (optional): the one rule learners forget.
- `examples`: exactly 3, each at most 12 words, everyday and easy (level of
  the package), natural Turkish translation, `highlight` = the exact words of
  the English sentence that show the rule (must appear in it verbatim).
- `mistake`: the most common learner mistake (`wrong`), the fix (`right`),
  and a one-line `note`.
- `check`: one easy warm-up question with a `----` blank, exactly 3 options,
  one clearly correct; `explanation` says why in one or two sentences.
- `examTip` (YDS only): the exam trap — how YDS tests this topic and the
  clue word to look for.

## 2. Answer explanations (`questionExplanations`, Business/Everyday)

`tr`: why the correct option is right — and, if useful, why the tempting
wrong one is wrong — in 1-3 short Turkish sentences. It must agree with the
answer key and with the English explanation. Quote the English words it
talks about. Do not translate the whole question.

## 3. Passage translation (`passageTR`)

A faithful, natural Turkish translation of the passage body; keep paragraph
breaks (`\n\n`). No additions, no omissions.

## 4. Word meanings (`wordMeanings`, Business/Everyday vocabulary)

The Turkish meaning of the headword in the sense the item's definition and
examples use — as a dictionary would give it: short, lower case (except
proper nouns), verbs in the infinitive ("uyanmak"), at most two senses
separated by ", " and only when the item covers both. For phrases give the
Turkish phrase ("mola vermek").
