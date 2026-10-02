# MathLearn iOS — Liquid Glass Visual Boundaries (APPROVED & IMPLEMENTED)

Source of truth: the three installed skills (`liquid-glass`, `liquid-glass-motion`,
`apple-motion-feel`) and their reference chain. Status: **APPROVED — all items implemented.**
Implementation: 2026-09-25. Two new files (`Theme/Motion.swift`, `Theme/Glass.swift`) + the
files in §10 edited surgically. Layouts, colors, navigation untouched. Hardware verification
in Xcode on a real device still REQUIRED before release (simulator is never glass acceptance).

The one spec deviation made during implementation: the flashcard "3D rotation" named in §6
does not exist in the code (the flip is a spring-animated content/color swap) — the Reduce
Motion branch was therefore implemented as a gentle crossfade on that swap, per §8.

**Amendment 2026-09-27 (user-approved):** bars chrome unification. Navigation bars AND the
tab bar now share one chrome style via `mlMatchingBarChrome()` (Theme/Glass.swift) —
`toolbarBackground(cream, .visible)` on both. This consciously amends the §9 "zero
toolbarBackground" migration-audit line: that rule banned scrims fighting Liquid Glass;
this change unifies the chrome with the canvas and composes WITH the glass (both bars
tinted identically on iOS 26; solid cream below 26). No scrims, no appearance proxies,
no scroll-edge overrides.

Design law for this app: the sticker system (cream / ink borders / hard shadows) is the
CONTENT layer and stays 100% solid. Glass appears only on the functional chrome that
floats above scrolling content. Content never gets glass. Max glass surfaces on any
screen: 3 (normally 2). That cap is the anti-blob guarantee.

---

## 1. Layer model (fixed vocabulary for the whole app)

| Layer | What lives there | Material |
|---|---|---|
| L0 Background | Flat cream fill, edge-to-edge | Solid color (never glass — nothing to defer to) |
| L1 Content | Scrollable sticker cards, text, video, charts, quiz cards, chat bubbles | Solid sticker style, untouched |
| L2 Floating chrome | System tab bar, system nav bars, onboarding FunnelHeader | Liquid Glass (the only glass zone) |
| L3 Modals | Sheets (More, Tools, Pricing, Account, Strategy, Legal) | System-managed; interiors stay solid cream |

Fixed vs floating: tab bar + nav bars = fixed system chrome. FunnelHeader = floating app
chrome. Everything else in the app is in-flow L1 content and stays solid.

## 2. Glass surfaces (complete, exhaustive list)

| ID | Surface | Where | Variant / shape | Size cap | Begin / end |
|---|---|---|---|---|---|
| G1 | System tab bar (5 tabs) | MainTabView | System-managed on iOS 26+ — no custom `glassEffect` | System-owned | Bottom safe-area capsule only; content scrolls behind it |
| G2 | System nav bars (every NavigationStack + MoreSheet) | All screens | System-managed | System-owned | Top safe area → bottom of inline title; soft scroll-edge fade beneath (system `.automatic`) |
| G3 | Onboarding FunnelHeader — back-button capsule + Skip pill | OnboardingFlowView overlay (top) | `.regular`, capsule `in:` shape, no tint | 44×44pt (back), ~70×32pt (Skip) | Each control is its own capsule; the progress bar and "auto" label between them stay SOLID |
| G4 | MoreToolbarButton exemption | ToolbarItem on Home/Lessons/Tutor/Progress | No glass — `sharedBackgroundVisibility(.hidden)` on iOS 26+ so the white sticker circle is exempt from the bar's shared material (sticker-on-glass would be glass-on-glass) | 32×32pt | — |

That is all. No other surface in the app receives glass. No tint on any glass surface
(tint = hierarchy signal; nothing here carries one).

## 3. Where glass is explicitly FORBIDDEN (the solid list)

- Every `stickerCard` / white card: hero, stats bar, feature tiles, course cards, lesson
  documents, formulas, examples, vocab, pricing/plan cards, account rows, achievements
- Question cards + option buttons — correct/wrong mint/coral is SEMANTIC color; meaning
  must never sit on a translucent material
- PracticeHubView white sub-tab bar (in-flow over flat cream: zero refraction input —
  glass there reads as a tinted rectangle per material-and-variants)
- AI chat bubbles, chat input bar (in-flow; no content passes beneath it)
- Difficulty pills, StickerBadge, StickerProgress, StatTile
- Video embed (WKWebView): never glass over it — hosted web content, YouTube's own
  chrome, display-rate backdrop (the unproven-over-glass case)
- Swift Charts (analytics), mastery tables, attribution/legal text — must stay sharp
- Onboarding plan cards, sticky trial footer, TrialSuccessView scrim + check circle
- ResultsCard, ConfettiView particles, flashcards (flip mechanic)
- Full-screen backgrounds, completion overlays

## 4. Merging & morphing (where one glass surface meets another)

- The only custom glass cluster is FunnelHeader (G3): back capsule + Skip pill. Their
  nearest edges are >100pt apart with a solid progress bar between → they deliberately
  NEVER merge. `GlassEffectContainer(spacing: 8)` so the threshold stays below the real
  gap; **no `glassEffectUnion`**. One container because two glass shapes coexist and one
  of them animates (container = correctness rule).
- M1 morph: back button appears on page ≥ 1 / disappears on page 0. Today it is
  `.opacity(0)` — on iOS 26 it becomes a real insertion/removal with `glassEffectID`
  ("back", shared `@Namespace`) inside the container, `withAnimation` at the mutation
  site. Reduce Motion → `glassEffectTransition(.materialize)` on the conditional child.
  Pre-26 fallback: today's exact opacity behavior.
- No other morphs exist. Tab selection, hub pills, quiz phase swaps are NOT glass morphs
  (they are solid-surface motion — see §5). Menu/glass combos: none (no Menus get glass).

## 5. Motion behavior (apple-motion-feel)

Named vocabulary only — new `MLMotion` constants, nothing else may be hand-tuned:

| Constant | Value | Used by |
|---|---|---|
| `MLMotion.press` | spring response 0.25, damping 0.9 (tap → critically damped per the damping table; current 0.7 slightly wobbles for a tap) | StickerButtonStyle press-down |
| `MLMotion.selection` | `.snappy` | hub tab lens, difficulty pills, lesson-quiz reveal |
| `MLMotion.page` | spring 0.45 / 0.9 (existing, now named) | onboarding page advance |
| `MLMotion.celebrate` | `.bouncy` | XP moments, confetti trigger |

Component rules:
- Buttons already respond on press (pointer-down ✓); track nothing during taps.
- M2 selection lens (PracticeHubView): `matchedGeometryEffect` glides the coral
  selection pill between the 4 hub tabs — solid surface, NOT glass, no material
  animation involved. Layout unchanged.
- M3 quiz/game phase swaps (intro → active → results): asymmetric `.transition`
  (insert: opacity + scale 0.96; remove: opacity) with the animation context OUTSIDE
  the `if` — the #1 silent-failure rule.
- M4 sheet zoom (optional delight): Pricing / Account / Strategy sheets zoom from their
  MoreSheet row via `matchedTransitionSource` + `navigationTransition(.zoom)` — iOS 18
  API, gated at 18, system-adapted for Reduce Motion (no custom gate).
- Numeric updates (XP, streak, quota): `.contentTransition(.numericText())` +
  `.animation(value:)`. Streak flame: `.symbolEffect(.bounce)` on increase. Both are
  system-adapted under Reduce Motion.
- Scroll: `tabBarMinimizeBehavior(.onScrollDown)` on MainTabView (iOS 26 gate) — the
  only scroll-linked chrome change. No custom scrims, no scroll-edge overrides
  (`.automatic` everywhere), no per-frame scroll state anywhere.
- Timer pill (≤5s yellow→coral): `.snappy` color crossfade.
- Confetti: unchanged (triggered, non-looping, hit-testing disabled).

## 6. Transition boundaries (exact seams)

| Boundary | Behavior |
|---|---|
| Tab switch | System animation; zero custom code |
| Navigation push/pop | System; toolbar controls lift into the glass bar themselves — never hand-animated |
| Funnel page swipe | Existing pager physics (`MLMotion.page`), header glass persists across pages |
| Sheet present/dismiss | System slide (M4 zoom where wired) |
| In-screen phase swaps | M3 asymmetric transition, context outside the conditional |
| Button press | Sticker press-down physics (`MLMotion.press`) |
| Success overlays | Opacity crossfade (already correct; RM-safe by default) |
| Flashcard flip | 3D rotation under motion → add Reduce Motion crossfade branch (rotation is a vestibular trigger) |

## 7. Availability & fallback discipline (deployment target = iOS 17.0)

- Every glass/26-only API sits in ONE gated `ViewModifier` (new `Theme/Glass.swift`) or
  inside a `.toolbar { if #available(iOS 26, *) … }` builder — never scattered, never a
  `.if` helper (banned: structural-identity destruction).
- Pre-26 fallback = "return self unchanged" (or today's exact style): the app on iOS
  17–25 looks precisely as it does today; no material-ladder imitations unless a surface
  needs to read as deliberate (G3 falls back to its current white-circle look).
- iOS 18 zoom: gated at 18 with standard-sheet fallback.
- No renamed/soft-deprecated API is emitted (`toolbarMinimizationBehavior` etc.), no
  known-bad symbols (no `scrollExtensionMode`, no `DefaultGlassEffectShape`, no
  `.glassBackgroundEffect`, no `ScrollEdgeEffectStyle.sharp`).
- Glass shapes go in `glassEffect(_:in:)` — never `.clipShape` on a glass view; hit
  areas restated with matching `contentShape`; no `rotationEffect` on glass; no opacity
  < 1 on any glass view or ancestor; no shadows/borders added to glass (system owns
  edges).

## 8. Accessibility commitments (owned by us, not the system)

- Reduce Motion gates PER COMPONENT on: M1 (→ `.materialize`), M3 (→ crossfade), M2
  lens (→ plain color swap), confetti (→ static check only), flashcard flip (→
  crossfade). Not one app-root check.
- Reduce Transparency / Increase Contrast: no code — the system frosts/starkens glass;
  we must NOT swap to `.identity`.
- VoiceOver: add labels to symbol-only controls (funnel back chevron, quiz exit, send
  plane); announce "+25 XP" state changes.
- Hit targets: flagging 32pt More button and 36pt funnel back button as below the 44pt
  touch minimum — fixing them is a size change, so it waits for your call.
- Dynamic Type: glass capsules size with their label; verified at accessibility sizes.

## 9. Performance notes

- ≤3 glass surfaces per screen, none in scrolling rows/cells → well inside the cost
  model; container shared where two coexist.
- Nothing glassed over a display-rate backdrop (video excluded by rule).
- No traces were run (Linux box, no toolchain) — hardware verification in Xcode on a
  real device is REQUIRED before sign-off (simulator is never glass acceptance).
- Migration phase-1 deletion audit: CLEAN — zero legacy scrims / `toolbarBackground` /
  `presentationBackground` / appearance proxies / material overrides exist in the
  codebase (verified by grep). Nothing to delete before adopting.

## 10. Files the implementation would touch (pending approval)

1. NEW `Theme/Motion.swift` — `MLMotion` constants + `adaptive(_:reduceMotion:)` helper
2. NEW `Theme/Glass.swift` — gated `GlassPanel` ViewModifier + toolbar-builder gates
3. `OnboardingFlowView.swift` — G3 container + M1 morph (layout unchanged)
4. `RootView.swift` — tab minimize gate, G4 exemption, M4 zoom sources (layout unchanged)
5. `PracticeHubView.swift` — M2 selection lens
6. `QuizStageView.swift`, `PracticeView.swift`, `MathGamesView.swift` — M3 transitions
7. `QuestionCardView.swift` — timer crossfade
8. `StickerDesignSystem.swift` — press-spring damping 0.7 → 0.9 + MLMotion adoption
9. `StudyToolsViews.swift` — flashcard Reduce Motion branch

Untouched: all Models/Services, catalog resources, colors, card styles, screen layouts,
navigation structure, web app (entirely).

## 11. Intentionally unchanged (summary)

The entire content layer (§3), all layouts, all colors, the pager physics, confetti,
sticker press feel (only damping tuned 0.7→0.9), the zero-press funnel timing, and the
web app. Glass exists in exactly 3 places (G1–G3) plus 1 exemption (G4). Everything
else is motion-only or nothing.
