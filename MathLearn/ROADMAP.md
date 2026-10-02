# MathLearn iOS — rewrite roadmap

## ✅ COMPLETE — the full app is ported (30 Swift files, ~8.5k lines)

- [x] **Design system** — sticker cards/pills/badges/progress/confetti (`StickerDesignSystem.swift`)
- [x] **Zero-press onboarding funnel** — auto-advance, auto-trial, auto-enter (`Features/Onboarding/`)
- [x] **Data layer** — `CatalogService` (19 bundled courses), `StudyStore` (XP/streaks/mastery/
      mistakes/notes/cards/attempts, JSON-persisted), verified video catalog (327 lessons
      with LLM notes) (`Services/`)
- [x] **Question engine** — full port of `questions.ts`: 13 topic generators × 4 difficulties
      with distractor construction (`Services/QuestionGenerator.swift`)
- [x] **Modules** — searchable course grid → units → lesson player (YouTube embed, formula/
      steps/examples/vocab/lesson quiz, attribution footer, mark-complete +25 XP)
      (`Features/Catalog/`)
- [x] **Practice engine** — endless adaptive drills (3-up / 2-down), timed 6-question quizzes,
      results with grade hero + confetti (`Features/Practice/`)
- [x] **Math Games** — Boss Battle (HP + combos), Speed Drill (60s), Equation Match —
      instructions flow + shared results (`Features/Games/`)
- [x] **Progress** — Swift Charts weekly XP, accuracy rings, per-topic mastery table,
      12-badge achievements gallery (`Features/Progress/`)
- [x] **AI features** — chat tutor (backend + offline fallback), photo solver, quiz maker,
      strategy study plan (`Features/AI/`, `Features/Tools/`)
- [x] **Tools** — flashcards, notes, mistake analyzer + repair mixes (`Features/Tools/`)
- [x] **Gamification & plan** — XP/streak engine, achievements, pricing tiers, trial card,
      account/settings, legal + attribution (`Features/Plan/`)

## Future polish (optional, not blocking 1:1 parity)

- [ ] StoreKit 2 real products (web uses Stripe; iOS mirror prices + trial via subscription service)
- [ ] Supabase auth parity + cloud sync of `StudyStore` snapshot
- [ ] Dark mode variant of the sticker palette (web funnel pinned light; app pins `.light`)
- [ ] Lesson slides mode (the web's per-slide `LessonSlidesViewer` rendering) — the document
      player covers the same content in scroll layout
- [ ] CloudKit backup of notes/flashcards

## Working agreement
- Every ported screen must visually match the sticker design system
  (`StickerDesignSystem.swift`) — no foreign palettes.
- Funnel must stay zero-press: any new step needs an auto-advance dwell.
