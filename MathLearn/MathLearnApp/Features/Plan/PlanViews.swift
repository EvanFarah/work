//
//  PricingView.swift + StrategyView.swift + AccountView.swift
//  MathLearn
//
//  Ports of PricingPage.tsx (3-tier plans mirroring plans.ts),
//  strategy (AI study plan), and AccountView/SettingsView/LegalView
//  (plan management, preferences, reset, attribution credits).
//

import SwiftUI

// MARK: - Pricing

struct PricingView: View {
    @EnvironmentObject private var subscription: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @State private var selected: PlanId = .plus

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        StickerBadge(text: "👑 Pricing", tone: MLColor.yellow, foreground: MLColor.ink)
                        Text("Pick your plan")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(MLColor.ink)
                        Text("Every plan starts with a 7-day free trial of Premium. Cancel anytime.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    ForEach(Plan.all) { plan in
                        planCard(plan)
                    }

                    if subscription.plan == .free && !subscription.isInTrial {
                        Button {
                            subscription.startTrial(plan: selected)
                            dismiss()
                        } label: {
                            Label("Start 7-Day Free Trial", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.stickerCoral)
                    } else if subscription.isInTrial {
                        trialCard
                    }

                    Text("Subscriptions renew monthly. Prices in USD. Restore anytime from Account → Manage plan.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Pricing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var trialCard: some View {
        let daysLeft = max(0, 7 - Int(Date().timeIntervalSince(subscription.trialStartDate ?? Date()) / 86400))
        return VStack(spacing: 6) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(MLColor.mintStrong)
                Text("Trial active — \(daysLeft) day\(daysLeft == 1 ? "" : "s") left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MLColor.ink)
                Spacer()
                StickerBadge(text: Plan.by(id: subscription.effectivePlan).name, tone: MLColor.purple, foreground: .white)
            }
            Text("You're getting Premium features free. When the trial ends you keep the \(Plan.by(id: subscription.plan).name) features.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(MLColor.mint.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MLColor.mintStrong, lineWidth: 2))
    }

    private func planCard(_ plan: Plan) -> some View {
        let isCurrent = subscription.plan == plan.id || (subscription.plan == .free && plan.id == .free && !subscription.isInTrial)
        return Button {
            selected = plan.id
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(plan.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(MLColor.ink)
                            if plan.id == .premium {
                                Text("MOST POWER")
                                    .font(.system(size: 8, weight: .semibold))
                                    .tracking(0.6)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(MLColor.purple)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(priceLine(plan))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: selected == plan.id ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(selected == plan.id ? MLColor.coral : .tertiary)
                }

                HStack(spacing: 8) {
                    quotaBadge("\(plan.quizzes)", "Quizzes/mo")
                    quotaBadge("\(plan.aiChats)", "AI chats/mo")
                    quotaBadge("\(plan.pptDecks)", "PPT decks/mo")
                }

                Text(featuresLine(plan.id))
                    .font(.caption)
                    .foregroundStyle(MLColor.ink.opacity(0.8))

                if isCurrent {
                    StickerBadge(text: "✓ Your current plan", tone: MLColor.mint, foreground: MLColor.ink)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected == plan.id ? MLColor.yellow.opacity(0.18) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(MLColor.ink, lineWidth: selected == plan.id ? 3 : 2))
            .shadow(color: MLColor.ink.opacity(0.8), radius: 0, x: 0, y: selected == plan.id ? 5 : 3)
        }
    }

    private func priceLine(_ plan: Plan) -> String {
        if plan.monthlyPrice == 0 { return "Free forever" }
        let monthly = NSDecimalNumber(decimal: plan.monthlyPrice).stringValue
        let annual = NSDecimalNumber(decimal: plan.annualMonthlyEquivalent).stringValue
        return "$\(monthly)/mo · $\(annual)/mo billed annually"
    }

    private func quotaBadge(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MLColor.ink)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(MLColor.cream)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func featuresLine(_ plan: PlanId) -> String {
        switch plan {
        case .free: return "PPT Maker · AI Chat · Quizzes · Auto-Learn Hints · Progress"
        case .plus: return "Everything in Free + Mistake Analyzer · Likely to Forget · Adaptive Study Plan"
        case .premium: return "Everything in Plus + Misconception Detector · Live Work Check"
        }
    }
}

// MARK: - Strategy (AI study plan)

struct StrategyView: View {
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var subscription: SubscriptionService

    private var isPlus: Bool { subscription.effectivePlan.rank >= PlanId.plus.rank }

    private struct PlanItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private var planItems: [PlanItem] {
        let weakest = Array(store.weakestTopics.prefix(3))
        guard !weakest.isEmpty else { return [] }
        return [
            PlanItem(
                icon: "flame.fill",
                title: "Warm up: \(weakest[0].topic.label)",
                detail: "Run a 6-question drill at medium difficulty to reactivate the skill."
            ),
            PlanItem(
                icon: "book.fill",
                title: "Learn: \(weakest[1].topic.label)",
                detail: "Open the weakest course lesson and finish the lesson quiz before practicing."
            ),
            PlanItem(
                icon: "bolt.fill",
                title: "Drill: \(weakest.count > 2 ? weakest[2].topic.label : weakest[0].topic.label)",
                detail: "Endless practice until you land 3 correct in a row at your current level."
            ),
            PlanItem(
                icon: "trophy.fill",
                title: "Finish strong: timed quiz",
                detail: "Bank XP with a 6-question timed quiz on today's focus topic."
            ),
        ]
    }

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        StickerBadge(text: "🧭 Strategy", tone: MLColor.mint, foreground: MLColor.ink)
                        Text("Today's study plan")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(MLColor.ink)
                        Text("Built from your live mastery data — the plan adapts every day you practice.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !isPlus {
                        VStack(spacing: 12) {
                            Text("⭐")
                                .font(.system(size: 38))
                            Text("Plus feature")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(MLColor.ink)
                            Text("The adaptive study plan is part of Plus — your 7-day free trial includes it.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            NavigationLink {
                                PricingView()
                            } label: {
                                Text("See plans")
                                    .frame(maxWidth: 220)
                            }
                            .buttonStyle(.stickerCoral)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .stickerCard()
                    } else if planItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.tertiary)
                            Text("Practice a few questions first")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(MLColor.ink)
                            Text("The plan builds itself once there's mastery data to learn from.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .stickerCard()
                    } else {
                        ForEach(Array(planItems.enumerated()), id: \.element.id) { i, item in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(i + 1)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(MLColor.coral)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Image(systemName: item.icon)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(MLColor.coral)
                                        Text(item.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(MLColor.ink)
                                    }
                                    Text(item.detail)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(14)
                            .stickerCard(radius: 16, lift: 3)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Strategy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Account & settings

struct AccountView: View {
    @EnvironmentObject private var subscription: SubscriptionService
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var ai: AIService
    @State private var showResetConfirm = false
    @State private var showLegal = false

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Plan card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            StickerBadge(
                                text: "\(Plan.by(id: subscription.effectivePlan).name) plan",
                                tone: subscription.effectivePlan == .free ? .white : MLColor.purple,
                                foreground: subscription.effectivePlan == .free ? MLColor.ink : .white
                            )
                            if subscription.isInTrial {
                                StickerBadge(text: "Trial", tone: MLColor.mint, foreground: MLColor.ink)
                            }
                            Spacer()
                        }
                        Text("Your plan, your data, your call.")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(MLColor.ink)
                        Text("Free forever · Plus $5.99/mo · Premium $6.99/mo — manage or upgrade below.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        NavigationLink {
                            PricingView()
                        } label: {
                            Label("Manage plan", systemImage: "crown.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.stickerYellow)
                    }
                    .padding(16)
                    .stickerCard()

                    // Stats snapshot
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SNAPSHOT")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            snapshotCell(value: "\(store.stats.xp)", label: "XP")
                            snapshotCell(value: "\(store.stats.level)", label: "Level")
                            snapshotCell(value: "\(store.stats.streakDays)", label: "Streak")
                            snapshotCell(value: "\(store.stats.lessonsCompleted.count)", label: "Lessons")
                        }
                    }
                    .padding(16)
                    .stickerCard(radius: 18, lift: 4)

                    // AI backend
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI BACKEND")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                        Text("The AI tutor and photo solver call the MathLearn web backend. Point them at your deployment:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("https://your-mathlearn-host", text: $ai.baseURL)
                            .font(.footnote.monospaced())
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(MLColor.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
                        Text("Leave unreachable for the built-in offline tutor — every feature still works.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .stickerCard(radius: 18, lift: 4)

                    // Legal + credits
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LEGAL & CREDITS")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                        Button {
                            showLegal = true
                        } label: {
                            legalRow(icon: "doc.text", label: "Privacy · Terms · Attribution")
                        }
                        Button {
                            showResetConfirm = true
                        } label: {
                            legalRow(icon: "arrow.counterclockwise.circle", label: "Reset all progress", tint: MLColor.coral)
                        }
                    }
                    .padding(16)
                    .stickerCard(radius: 18, lift: 4)

                    Text("MathLearn iOS · native SwiftUI build v1.0")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Reset all progress? XP, streaks, mistakes, notes, and flashcards will be erased. This cannot be undone.",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Erase everything", role: .destructive) { store.resetAll() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showLegal) {
            LegalView()
        }
    }

    private func snapshotCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MLColor.ink)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(MLColor.cream)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func legalRow(icon: String, label: String, tint: Color = MLColor.ink) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(MLColor.cream)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Legal (privacy / terms / attribution)

struct LegalView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MLColor.cream.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        legalSection(
                            badge: "Privacy",
                            tone: .blue,
                            body: """
                            MathLearn stores your learning data — XP, streaks, mastery, mistakes, notes, and flashcards — locally on this device. Nothing is uploaded to a server unless you connect the AI backend in Account → AI backend, in which case only the messages you send to the tutor are transmitted. We don't collect analytics, identifiers, or advertising data. Deleting the app erases everything.
                            """
                        )
                        legalSection(
                            badge: "Terms",
                            tone: .yellow,
                            body: """
                            MathLearn is provided for personal, educational use. The 7-day free trial grants Premium features for seven days from activation and can be used once per device. Plans renew monthly as described on the Pricing screen; cancel anytime from your App Store subscription settings. Abuse of the service or the content license terminates your right to use the app.
                            """
                        )
                        legalSection(
                            badge: "Attribution",
                            tone: .mint,
                            body: """
                            Lesson videos are by James Sousa (Mathispower4u), used with attribution under the channel's stated license. Each lesson that ships with a video shows the author, publisher, and license directly beneath the player, with a link to the original upload. Course mini-lesson documents are original MathLearn curriculum content.
                            """
                        )
                        legalSection(
                            badge: "Contact",
                            tone: .purple,
                            body: """
                            Questions, takedown requests, or license questions: reach the team through the repository issue tracker. Content owners can request review of any referenced material at any time.
                            """
                        )
                    }
                    .padding(16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Legal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func legalSection(badge: String, tone: Tone, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            StickerBadge(text: badge, tone: tone)
            Text(body)
                .font(.footnote)
                .foregroundStyle(MLColor.ink)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stickerCard(radius: 18, lift: 4)
    }
}
