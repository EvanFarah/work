//
//  OnboardingSteps.swift
//  MathLearn
//
//  The three funnel pages, ported from StepHook.tsx / StepCompare.tsx /
//  StepPlans.tsx. Same copy, same decoy structure (Premium pre-selected,
//  "Most Popular" coral badge, $1-more upsell chip), same escape hatches.
//

import SwiftUI

// MARK: - Page 1 · Hook

struct StepHookView: View {
    var onContinue: () -> Void

    private let features: [(icon: String, title: String, body: String, tint: Color)] = [
        ("bolt.fill", "Real-Time Error Checker", "Scans your step-by-step math and alerts you the exact second you make a sign error or calculation mistake.", MLColor.yellow),
        ("brain", "Mistake Analyzer", "Doesn't just give the answer — explains the underlying logic error so you actually learn.", MLColor.purple.opacity(0.25)),
        ("note.text", "Smart Notebook & Repair Mixes", "Auto-organizes your weak spots into targeted 3-question warm-ups.", MLColor.mint.opacity(0.3)),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Stop losing points to silly mistakes.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                    .padding(.top, 24)

                ForEach(features.indices, id: \.self) { i in
                    let f = features[i]
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: f.icon)
                            .frame(width: 40, height: 40)
                            .background(f.tint)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(MLColor.ink)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(f.title).font(.headline).foregroundStyle(MLColor.ink)
                            Text(f.body).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .stickerCard()
                }

                Label("Trusted by 10,000+ students & parents", systemImage: "star.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(MLColor.ink)

                Button(action: onContinue) {
                    Label("Get Started", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.stickerCoral)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 20)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

// MARK: - Page 2 · Comparison

struct StepCompareView: View {
    var onContinue: () -> Void

    private let rows: [(String, [String])] = [
        ("AI Chats / month", ["200", "1,000", "5,000"]),
        ("Quizzes / month", ["20", "100", "500"]),
        ("PPT Maker decks", ["5 / mo", "50 / mo", "100 / mo"]),
        ("Auto-Learn Hints", ["✓", "✓", "✓"]),
        ("Mistake Analyzer", ["—", "Included", "Included"]),
        ("Likely to Forget + %", ["—", "Included", "Included"]),
        ("Misconception Detector", ["—", "—", "Included"]),
        ("Live Work Check", ["—", "—", "Included"]),
    ]
    private let tiers = ["Free", "Plus", "Premium"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Choose How You Want to Study")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 10) {
                    Text("“I went from a C+ to an A− in Algebra 2 in 3 weeks — MathLearn caught my silly sign mistakes before I submitted my homework.”")
                        .font(.subheadline)
                        .foregroundStyle(MLColor.ink)
                    Label("High School Student", systemImage: "graduationcap.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .stickerCard()

                // Plan matrix — Premium column softly tinted toward the eye.
                VStack(spacing: 0) {
                    HStack {
                        Text("Feature").font(.caption.weight(.heavy)).frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(tiers, id: \.self) { t in
                            Text(t)
                                .font(.caption.weight(.heavy))
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(t == "Premium" ? MLColor.ink : .secondary)
                        }
                    }
                    .padding(12)
                    ForEach(rows, id: \.0) { row in
                        HStack {
                            Text(row.0).font(.caption.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(Array(row.1.enumerated()), id: \.offset) { _, cell in
                                Text(cell)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(row.0 == "Quizzes / month" ? MLColor.mint.opacity(0.08) : .clear)
                    }
                }
                .stickerCard()

                Button(action: onContinue) {
                    Label("Unlock Unlimited Mastery", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.stickerCoral)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Page 3 · Plans (conversion)

struct StepPlansView: View {
    var onStartTrial: (PlanId, Bool) -> Void
    var onContinueFree: () -> Void
    var onSelectionChange: (TrialSelection) -> Void

    @State private var annual = false
    @State private var selected: PlanId = .premium // decoy: Premium pre-picked

    private struct PriceLine {
        let main: String
        let strike: String?
        let sub: String
    }

    private func price(for plan: PlanId) -> PriceLine {
        let p = Plan.by(id: plan)
        if annual {
            return PriceLine(main: "$\(p.annualMonthlyEquivalent)", strike: "$\(p.monthlyPrice)", sub: "Billed yearly")
        }
        return PriceLine(main: "$\(p.monthlyPrice)", strike: nil, sub: "Billed monthly")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select Your Plan")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(MLColor.ink)
                        .padding(.top, 24)
                    Text("Cancel anytime with one tap. Zero risk.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    // Billing toggle (Annual = Save 45%)
                    HStack(spacing: 0) {
                        billingTab("Monthly", active: !annual) { annual = false }
                        billingTab("Annual", active: annual) { annual = true }
                    }
                    .background(MLColor.ink.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1))

                    planCard(.plus, badge: "Standard Homework Prep")
                    planCard(.premium, badge: nil)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            // Pinned conversion footer — the trial CTA never floats mid-content.
            VStack(spacing: 10) {
                Button {
                    onStartTrial(selected, annual)
                } label: {
                    Text("Start 7-Day Free Trial")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.stickerCoral)

                Label("100% Satisfaction Guarantee · Cancel anytime", systemImage: "checkmark.shield")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                Button("Continue with Limited Free Version", action: onContinueFree)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(MLColor.cream)
            .overlay(alignment: .top) { Rectangle().fill(MLColor.ink.opacity(0.1)).frame(height: 1) }
        }
        .onChange(of: selected) { _, newValue in onSelectionChange(TrialSelection(plan: newValue, annual: annual)) }
        .onChange(of: annual) { _, newValue in onSelectionChange(TrialSelection(plan: selected, annual: newValue)) }
        .onAppear { onSelectionChange(TrialSelection(plan: selected, annual: annual)) }
    }

    private func billingTab(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(active ? MLColor.ink : .secondary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(active ? .white : .clear)
                .clipShape(Capsule())
        }
    }

    private func planCard(_ plan: PlanId, badge: String?) -> some View {
        let isSelected = selected == plan
        let price = price(for: plan)
        let p = Plan.by(id: plan)

        return Button {
            selected = plan
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(p.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(MLColor.ink)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(MLColor.ink.opacity(0.06))
                            .clipShape(Capsule())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        if let strike = price.strike {
                            Text(strike).strikethrough().font(.caption).foregroundStyle(.tertiary)
                        }
                        Text(price.main).font(.system(size: 18, weight: .bold)).foregroundStyle(MLColor.ink)
                    }
                }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(MLColor.mintStrong)
                    Text("\(p.quizzes) Quizzes · \(p.aiChats) AI Chats · \(p.pptDecks) PPT Decks\(p.id == .premium ? " · Live Work Check" : "")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if plan == .premium {
                    StickerBadge(text: "Just $1 more for 5× higher limits")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(isSelected ? (plan == .premium ? MLColor.coral : MLColor.ink) : MLColor.ink.opacity(0.15), lineWidth: 3)
            )
            .shadow(color: (isSelected && plan == .premium) ? MLColor.coral.opacity(0.45) : MLColor.ink.opacity(0.25), radius: 0, x: 0, y: 6)
        }
        .overlay(alignment: .top) {
            if plan == .premium {
                StickerBadge(text: "Most Popular — Best Value", tone: MLColor.coral, foreground: .white)
                    .offset(y: -14)
            }
        }
        .padding(.top, plan == .premium ? 14 : 0)
    }
}
