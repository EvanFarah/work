//
//  OnboardingFlowView.swift
//  MathLearn
//
//  SwiftUI port of src/components/onboarding/OnboardingFlow.tsx —
//  the ZERO-PRESS multipage paywall: pages 1-2 advance on their own
//  (5s / 6.5s), page 3 auto-starts the 7-day trial with the visitor's
//  current plan selection after a 9s dwell, and the success overlay
//  auto-enters the app after 3s. Any deliberate interaction disarms
//  auto-play and hands control back (drag, tap, scroll intent).
//

import SwiftUI

struct OnboardingFlowView: View {
    var onFinish: () -> Void

    @EnvironmentObject private var subscription: SubscriptionService

    @State private var page = 0
    @State private var autoArmed = true
    @State private var selection = TrialSelection(plan: .premium, annual: false)
    @State private var trialStarted = false

    @State private var autoTask: Task<Void, Never>?

    private let pageDwells: [TimeInterval] = [5, 6.5, 9] // page 3 = auto-trial
    private let successAutoEnter: TimeInterval = 3

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()

            TabView(selection: $page) {
                StepHookView(onContinue: { disarmAndGo(1) })
                    .tag(0)
                StepCompareView(onContinue: { disarmAndGo(2) })
                    .tag(1)
                StepPlansView(
                    onStartTrial: startTrial,
                    onContinueFree: onFinish,
                    onSelectionChange: { selection = $0 }
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)
            .simultaneousGesture(
                DragGesture(minimumDistance: 24).onEnded { _ in disarmAuto() }
            )
        }
        .overlay {
            if trialStarted {
                TrialSuccessView(planName: Plan.by(id: selection.plan).name) {
                    onFinish()
                }
                .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            FunnelHeader(page: page, autoActive: autoArmed && !trialStarted, onBack: {
                disarmAuto()
                page = max(0, page - 1)
            }, onSkip: onFinish)
        }
        .overlay(alignment: .topTrailing) {
            // Skip — pinned to the screen's true top-right corner, where users
            // instinctively look for a close affordance (web parity: the X sits
            // outside the centered header row). Still REAL Liquid Glass on
            // iOS 26 (floating functional layer, G2-compliant); hidden once the
            // trial success overlay owns the screen.
            if !trialStarted {
                Button(action: onFinish) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.secondary)
                        .mlFunnelSkipGlass()
                }
                .accessibilityLabel("Skip onboarding")
                .padding(.trailing, 12)
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: trialStarted)
        .onAppear { scheduleAuto(for: page) }
        .onChange(of: page) { _, newPage in
            scheduleAuto(for: newPage)
        }
        .onDisappear { autoTask?.cancel() }
    }

    // MARK: - Auto-play (hands-free funnel)

    /// Dwell timer per page. Page 3's dwell AUTO-STARTS THE TRIAL with the
    /// visitor's current selection — the last required press was removed.
    private func scheduleAuto(for pageIndex: Int) {
        autoTask?.cancel()
        guard autoArmed, !trialStarted else { return }
        let dwell = pageDwells[pageIndex]
        autoTask = Task { [weak subscription] in
            try? await Task.sleep(for: .seconds(dwell))
            guard !Task.isCancelled else { return }
            if pageIndex == pageDwells.count - 1 {
                startTrial(plan: selection.plan, annual: selection.annual)
            } else {
                withAnimation(MLMotion.page) {
                    page = pageIndex + 1
                }
            }
            _ = subscription // keeps the environment capture explicit
        }
    }

    private func disarmAuto() {
        autoArmed = false
        autoTask?.cancel()
    }

    private func disarmAndGo(_ next: Int) {
        disarmAuto()
        withAnimation(MLMotion.page) { page = next }
    }

    // MARK: - Conversion

    private func startTrial(plan: PlanId, annual: Bool) {
        disarmAuto()
        subscription.startTrial(plan: plan)
        trialStarted = true
        // Auto-enter the app — the trial CTA was the last required press.
        Task {
            try? await Task.sleep(for: .seconds(successAutoEnter))
            guard !Task.isCancelled else { return }
            onFinish()
        }
    }
}

// MARK: - Trial selection lifted from the pricing page

struct TrialSelection {
    var plan: PlanId
    var annual: Bool
}

// MARK: - Header (progress + auto indicator + skip)

private struct FunnelHeader: View {
    let page: Int
    let autoActive: Bool
    let onBack: () -> Void
    let onSkip: () -> Void

    @Namespace private var glassNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            // M1 — the back control is REAL Liquid Glass on iOS 26 and is
            // inserted/removed (never opacity-faded: glass may not run at
            // opacity < 1). The fixed 36pt slot reserves its footprint so
            // the morph never reflows the progress bar (layout unchanged).
            // System morph runs from the animation bound to `page`; under
            // Reduce Motion the system materializes in place instead.
            ZStack {
                if page > 0 {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .frame(width: 36, height: 36)
                            .foregroundStyle(MLColor.ink)
                            .mlFunnelBackGlass()
                            .mlGlassID("funnel-back", in: glassNS)
                            .mlGlassMorphStyle(reduceMotion: reduceMotion)
                    }
                    .accessibilityLabel("Back")
                }
            }
            .frame(width: 36, height: 36)
            .animation(MLMotion.adaptive(MLMotion.page, reduceMotion: reduceMotion), value: page)

            // SOLID by law — the progress bar and auto label are content,
            // never glass (spec §2 G3).
            ProgressView(value: Double(page + 1), total: 3)
                .tint(MLColor.ink)

            if autoActive {
                Label("auto", systemImage: "circle.dotted")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            // (Skip moved to the top-trailing corner overlay — the natural
            // close-affordance spot. The header keeps back + progress + auto.)
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        // G3 — the back chevron is the header's only glass surface now (the
        // skip moved to its own top-trailing corner overlay, dozens of points
        // away). Independent containers = the surfaces can never merge.
        .mlGlassContainer(spacing: 8)
    }
}

// MARK: - Success overlay (mirrors the web success modal)

struct TrialSuccessView: View {
    let planName: String
    var onEnter: () -> Void

    var body: some View {
        ZStack {
            MLColor.cream.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                    .frame(width: 64, height: 64)
                    .background(MLColor.mint)
                    .clipShape(Circle())
                    .stickerCard(radius: 32, lift: 0)

                Text("Your 7-day free trial has started")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                    .multilineTextAlignment(.center)

                Text("\(planName) plan · Cancel anytime. Zero risk.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    onEnter()
                } label: {
                    Label("Start Learning", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.stickerCoral)
            }
            .padding(28)
            .frame(maxWidth: 380)
        }
    }
}
