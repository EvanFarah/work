//
//  RootView.swift
//  MathLearn
//
//  Port of OnboardingGate.tsx + MobileNav.tsx: first launch → zero-press
//  funnel; afterwards → the main app with the mobile tab layout
//  (Home / Practice / Modules / AI Tutor / Progress) plus the "More"
//  grid covering every remaining destination from the web nav.
//

import SwiftUI

struct RootView: View {
    @AppStorage("mathlearn.onboarded.v2") private var onboarded = false

    var body: some View {
        if onboarded {
            MainTabView()
        } else {
            OnboardingFlowView {
                onboarded = true // funnel finished (or skipped) → straight in
            }
        }
    }
}

// MARK: - Main app shell (MobileNav.tsx port)

struct MainTabView: View {
    @State private var selection: MainTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(MainTab.home)
            PracticeHubView()
                .tabItem { Label("Practice", systemImage: "bolt.fill") }
                .tag(MainTab.practice)
            ModulesView()
                .tabItem { Label("Lessons", systemImage: "book.fill") }
                .tag(MainTab.lessons)
            AITutorView()
                .tabItem { Label("AI Tutor", systemImage: "bubble.left.and.text.bubble.right.fill") }
                .tag(MainTab.tutor)
            ProgressHubView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(MainTab.progress)
        }
        .tint(MLColor.coral)
        // Bottom bar matches the top bars: one shared chrome style (cream,
        // always visible) on every OS version — see Glass.swift.
        .mlMatchingBarChrome()
        // G1 — the system tab bar IS the glass surface on iOS 26; the only
        // scroll-linked chrome change in the app. No custom scrims.
        .mlTabBarMinimizeOnScroll()
        .onReceive(NotificationCenter.default.publisher(for: .mlMainTabRequest)) { note in
            if let tab = note.userInfo?["tab"] as? MainTab {
                selection = tab
            }
        }
    }
}

// MARK: - More sheet (SECTIONS from MobileNav.tsx)

struct MoreSheet: View {
    var dismiss: () -> Void
    @Environment(\.dismiss) private var autoDismiss
    @Namespace private var zoomNS
    @State private var showTools = false
    @State private var showPricing = false
    @State private var showAccount = false
    @State private var showLegal = false
    @State private var showQuizMaker = false
    @State private var showStrategy = false
    @State private var showFlashcards = false
    @State private var showNotes = false
    @State private var showMistakes = false
    @State private var showDetector = false
    @State private var showLikelyForget = false
    @State private var showPhotoSolver = false
    @State private var showPPTMaker = false
    @State private var showLiveWorkCheck = false

    private struct Row: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let desc: String
        let plan: PlanId?
        var zoomKey: String? = nil // M4 — set on rows whose sheet zooms
        let action: () -> Void
    }

    private var sections: [(title: String, rows: [Row])] {
        [
            ("Main", [
                Row(icon: "square.grid.2x2.fill", label: "Modules", desc: "Browse 19 courses from 1st grade to college-level math", plan: nil, action: { dismiss() }),
                Row(icon: "lightbulb.fill", label: "Strategy", desc: "AI builds an adaptive study plan around your gaps", plan: .plus, zoomKey: "strategy", action: { showStrategy = true }),
            ]),
            ("Practice", [
                Row(icon: "wand.and.stars", label: "Quiz Maker", desc: "Build custom quizzes on any topic and difficulty", plan: nil, action: { showQuizMaker = true }),
                Row(icon: "gamecontroller.fill", label: "Math Games", desc: "Battle math bosses and earn XP", plan: nil, action: { dismiss() }),
            ]),
            ("AI Tools", [
                Row(icon: "doc.richtext.fill", label: "PPT Maker", desc: "Turn any topic into a shareable study deck", plan: nil, action: { showPPTMaker = true }),
                Row(icon: "camera.fill", label: "Photo Solver", desc: "Snap a problem — get step-by-step help", plan: nil, action: { showPhotoSolver = true }),
            ]),
            ("Tools", [
                Row(icon: "rectangle.on.rectangle.angled.fill", label: "Flashcards", desc: "Tap-to-flip deck review", plan: nil, action: { showFlashcards = true }),
                Row(icon: "square.and.pencil", label: "Notes", desc: "Formulas, tricks, and reminders", plan: nil, action: { showNotes = true }),
                Row(icon: "stethoscope", label: "Mistake Analyzer", desc: "Press explain-why-wrong after solving — get the logic", plan: .plus, action: { showMistakes = true }),
                Row(icon: "brain.filled.head.profile", label: "Likely to Forget", desc: "Topics slipping, with a percentage — from stats & time", plan: .plus, action: { showLikelyForget = true }),
                Row(icon: "brain.head.profile", label: "Misconception Detector", desc: "Scans all mistakes for recurring error types", plan: .premium, action: { showDetector = true }),
                Row(icon: "checkmark.seal.fill", label: "Live Work Check", desc: "Checks your working line by line as you solve", plan: .premium, action: { showLiveWorkCheck = true }),
            ]),
            ("Account", [
                Row(icon: "crown.fill", label: "Pricing", desc: "Free forever · Plus $5.99/mo · Premium $6.99/mo", plan: nil, zoomKey: "pricing", action: { showPricing = true }),
                Row(icon: "gearshape.fill", label: "Account & Settings", desc: "Your plan, preferences, and legal", plan: nil, zoomKey: "account", action: { showAccount = true }),
            ]),
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MLColor.cream.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(sections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .textCase(.uppercase)
                                    .tracking(1)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)

                                VStack(spacing: 8) {
                                    ForEach(section.rows) { row in
                                        Button(action: row.action) {
                                            HStack(spacing: 12) {
                                                Image(systemName: row.icon)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundStyle(MLColor.ink)
                                                    .frame(width: 38, height: 38)
                                                    .background(MLColor.cream)
                                                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(row.label)
                                                        .font(.system(size: 15, weight: .semibold))
                                                        .foregroundStyle(MLColor.ink)
                                                    Text(row.desc)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .multilineTextAlignment(.leading)
                                                }
                                                Spacer(minLength: 6)
                                                if let plan = row.plan, plan != .free {
                                                    StickerBadge(
                                                        text: plan == .plus ? "⭐ Plus" : "👑 Premium",
                                                        tone: plan == .plus ? MLColor.blue : MLColor.purple,
                                                        foreground: plan == .plus ? MLColor.ink : .white
                                                    )
                                                }
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .stickerCard(radius: 18, lift: 4)
                                        }
                                        // M4 — rows whose sheets zoom register as
                                        // system zoom origins (iOS 18, inert otherwise).
                                        .mlZoomSource(row.zoomKey != nil, id: row.zoomKey ?? "", in: zoomNS)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { autoDismiss() }
                        .font(.callout.weight(.bold))
                }
            }
            .sheet(isPresented: $showQuizMaker) { QuizMakerView() }
            .sheet(isPresented: $showFlashcards) { FlashcardsView() }
            .sheet(isPresented: $showNotes) { NotesView() }
            .sheet(isPresented: $showMistakes) { MistakeAnalyzerView() }
            .sheet(isPresented: $showDetector) { NavigationStack { MisconceptionDetectorView() } }
            .sheet(isPresented: $showLikelyForget) { NavigationStack { LikelyToForgetView() } }
            .sheet(isPresented: $showPhotoSolver) { PhotoSolverView() }
            .sheet(isPresented: $showPPTMaker) { PPTMakerView() }
            .sheet(isPresented: $showLiveWorkCheck) { NavigationStack { LiveWorkCheckView() } }
            .sheet(isPresented: $showPricing) { NavigationStack { PricingView() }.mlZoomTarget(id: "pricing", in: zoomNS) }
            .sheet(isPresented: $showAccount) { NavigationStack { AccountView() }.mlZoomTarget(id: "account", in: zoomNS) }
            .sheet(isPresented: $showStrategy) { NavigationStack { StrategyView() }.mlZoomTarget(id: "strategy", in: zoomNS) }
        }
    }
}

// MARK: - Shared "More" toolbar button

struct MoreToolbarButton: View {
    @State private var showMore = false

    var body: some View {
        Button { showMore = true } label: {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MLColor.ink)
                .frame(width: 32, height: 32)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
        }
        // G4 — exempt the sticker circle from the toolbar's shared glass
        // material: a sticker ON glass would be the banned glass-on-glass.
        .mlToolbarSharedBackgroundHidden()
        .sheet(isPresented: $showMore) {
            MoreSheet(dismiss: { showMore = false })
        }
    }
}
