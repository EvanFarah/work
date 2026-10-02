# MathLearn for iOS — full native SwiftUI app

Native SwiftUI port of the **entire** MathLearn web app
(`/src` → `/ios/MathLearn`). 30 Swift files, ~8.5k lines, zero
third-party dependencies, fully offline-capable.

> **Build note:** this repository lives on a Linux container, so the Swift
> sources here are **not compiled in CI**. Open the project on a Mac with
> Xcode 16+ and it builds as-is.

## Open in Xcode

**Option A — Xcode folder sync (fastest):**
1. Copy `ios/MathLearn/` to a Mac.
2. Xcode ▸ **File ▸ Open…** ▸ select the `MathLearn` folder.
3. Set a bundle id + signing team, pick an iOS 17+ simulator, Run.

**Option B — XcodeGen project:**
```bash
brew install xcodegen
cd ios/MathLearn && xcodegen generate
open MathLearn.xcodeproj
```

## What ships (complete app)

| Web source | Swift file(s) | Notes |
|---|---|---|
| `globals.css` sticker design system | `Theme/StickerDesignSystem.swift` | palette, sticker cards, pill buttons, hard shadows, progress bars, difficulty pills, confetti |
| `OnboardingGate/OnboardingFlow/Steps` | `Features/Onboarding/*` | **zero-press funnel**: auto-advance, page-3 dwell auto-starts the trial, success overlay auto-enters |
| `MobileNav.tsx` | `Features/Root/RootView.swift` | 5-tab shell (Home/Practice/Lessons/AI Tutor/Progress) + full **More** grid |
| `DashboardView.tsx` | `Features/Home/HomeView.swift` | Jump-Back-In hero, XP/streak/mastery bar, feature grid, Explore All Levels |
| `lessons/index.json` + 19 course JSONs | `Resources/Catalog/` | bundled course catalog, decoded by `CatalogService` |
| import pipeline (`ImportedVideo`, 327 verified) | `Resources/Videos/videos.json` | license-verified Mathispower4u videos with LLM lesson notes |
| `LearnStage/LessonSlidesViewer` | `Features/Catalog/LessonPlayerView.swift` | YouTube embed (WKWebView), formulas, steps, examples, vocabulary, lesson quiz, **attribution footer** |
| `PracticeView` | `Features/Practice/PracticeView.swift` | endless adaptive drills — **3 correct → harder, 2 wrong → easier** |
| `QuizzesView + QuizStage + QuestionCard` | `QuizSetupView / QuizStageView / QuestionCardView` | timed 6-question quizzes, countdown, review bar, results |
| `ResultsCard` | `Features/Practice/ResultsCardView.swift` | S/A/B/C/D/F grade hero, confetti, retry/new-topic |
| `MathGamesView` + boss system | `Features/Games/*` | **Boss Battle** (HP + combos), **Speed Drill** (60s), **Equation Match** — instructions flow + shared results |
| `FlashcardsView` / `NotesView` | `Features/Tools/StudyToolsViews.swift` | flip-deck review, tagged notepad |
| `MistakeAnalyzerView` | `Features/Tools/AdvancedToolsViews.swift` | mistake tracking, offline analysis, weakness finder, 3-question **repair mixes** — **Plus** |
| `QuizMakerView` | same file | custom quiz builder (subject/topic/difficulty/length) |
| `PhotoSolverView` | same file | PhotosPicker → backend `/api/image`, offline fallback |
| `PPTMakerView` | `Features/Tools/PPTMakerView.swift` | **Free** study-deck generator (method/example/your-turn slides), monthly deck quota, ShareLink outline export |
| `LiveWorkCheckView` | `Features/Tools/LiveWorkCheckView.swift` | **Premium** line-by-line work checker — recursive-descent arithmetic engine flags sign / off-by-one / ×10 / transposed slips as you type |
| `AIChatView` | `Features/AI/AITutorView.swift` | chat tutor → `/api/chat`, typing indicator, quota meter, offline tutor |
| `ProgressHub/Statistics/Achievements` | `Features/Progress/ProgressHubView.swift` | Swift Charts weekly XP, accuracy rings, per-topic mastery table, 12-badge gallery |
| `PricingPage` + plans.ts | `Features/Plan/PlanViews.swift` | 3 tier cards with quotas, trial card, plan management |
| Strategy / Account / Settings / Legal | same file | adaptive study plan, AI backend config, reset, privacy/terms/**attribution** |
| study-store (zustand) | `Services/StudyStore.swift` | XP, streaks, mastery, mistakes, notes, cards, attempts, daily XP — persisted to JSON |

## Architecture

- **Services** are `@MainActor` `ObservableObject`s injected once at the app
  root (`StudyStore`, `CatalogService`, `SubscriptionService`, `AIService`).
- **QuestionGenerator** is a faithful port of `src/lib/math/questions.ts` —
  13 topic generators with difficulty ranges and distractor construction.
- **AI** calls the web backend's routes when configured (Account → AI
  backend) and otherwise uses the built-in `LocalTutor`, so every feature
  works offline.
- Feature folders mirror the web's `src/components/study` groupings.

## Regenerating bundled data

```bash
# from the repo root
bun scripts/ios-export-videos.ts     # re-export verified videos from the import DB
cp public/lessons/index.json ios/MathLearn/MathLearnApp/Resources/Catalog/
cp public/lessons/courses/*.json ios/MathLearn/MathLearnApp/Resources/Catalog/courses/
python3 scripts/ios-swift-audit.py   # structural sanity audit of all Swift sources
```
