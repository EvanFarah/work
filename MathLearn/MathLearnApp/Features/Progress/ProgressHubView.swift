//
//  ProgressHubView.swift
//  MathLearn
//
//  Port of ProgressHubView/StatisticsView/AchievementsView — three
//  tabs: Analytics (weekly XP bar chart + accuracy rings via Swift
//  Charts), Statistics (lifetime counters + per-topic mastery table),
//  and Achievements (the 12-badge gallery).
//

import SwiftUI
import Charts

struct ProgressHubView: View {
    private enum Tab: String, CaseIterable {
        case analytics = "Analytics"
        case statistics = "Statistics"
        case achievements = "Achievements"
    }
    @State private var tab: Tab = .analytics

    var body: some View {
        NavigationStack {
            ZStack {
                MLColor.cream.ignoresSafeArea()
                VStack(spacing: 0) {
                    tabPicker
                    ScrollView {
                        VStack(spacing: 16) {
                            switch tab {
                            case .analytics: AnalyticsView()
                            case .statistics: StatisticsView()
                            case .achievements: AchievementsView()
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { MoreToolbarButton() } }
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { tab = t }
                } label: {
                    Text(t.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(tab == t ? MLColor.coral : Color.white)
                        .foregroundStyle(tab == t ? Color.white : MLColor.ink.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(5)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(MLColor.ink, lineWidth: 2.5))
        .shadow(color: MLColor.ink.opacity(0.85), radius: 0, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Analytics (charts)

private struct AnalyticsView: View {
    @EnvironmentObject private var store: StudyStore

    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(
                badgeText: "📈 Analytics",
                badgeTone: .blue,
                title: "Your analytics",
                subtitle: "Weekly XP, answer volume, and accuracy at a glance."
            )

            // Weekly XP chart
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    StickerBadge(text: "XP this week", tone: MLColor.yellow, foreground: MLColor.ink)
                    Spacer()
                    Text("total \(store.weeklyXP.reduce(0) { $0 + $1.xp })")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.secondary)
                }
                Chart(store.weeklyXP, id: \.day) { day in
                    BarMark(
                        x: .value("Day", day, unit: .day),
                        y: .value("XP", day.xp)
                    )
                    .foregroundStyle(MLColor.coral)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .font(.caption2)
                    }
                }
                .frame(height: 150)
            }
            .padding(16)
            .stickerCard(radius: 18, lift: 4)

            // Accuracy + volume
            HStack(spacing: 12) {
                ringCard(
                    value: Double(store.stats.accuracy),
                    title: "Accuracy",
                    tint: MLColor.mint,
                    caption: "\(store.stats.totalCorrect)/\(store.stats.totalAnswered) correct"
                )
                ringCard(
                    value: Double(store.stats.overallMastery),
                    title: "Mastery",
                    tint: MLColor.blue,
                    caption: "across \(activeTopics) topics"
                )
            }

            // Recent attempts
            if !store.attempts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    StickerBadge(text: "Recent sessions", tone: .white)
                    ForEach(store.attempts.prefix(5)) { attempt in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(MLColor.mintStrong)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(attempt.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(MLColor.ink)
                                Text("\(attempt.subject) · \(attempt.difficulty.rawValue)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(attempt.score)/\(attempt.total)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(MLColor.ink)
                                Text("+\(attempt.xpEarned) XP")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(MLColor.mintStrong)
                            }
                        }
                        .padding(10)
                        .background(MLColor.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(14)
                .stickerCard(radius: 18, lift: 4)
            }
        }
    }

    private var activeTopics: Int {
        max(1, store.stats.mastery.values.filter { $0 > 0 }.count)
    }

    private func ringCard(value: Double, title: String, tint: Color, caption: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, value / 100)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value))%")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(MLColor.ink)
            }
            .frame(width: 92, height: 92)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(MLColor.ink)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .stickerCard(radius: 18, lift: 4)
    }
}

// MARK: - Statistics (lifetime + per-topic)

private struct StatisticsView: View {
    @EnvironmentObject private var store: StudyStore

    private var topicRows: [(subject: String, label: String, topic: MathTopic, mastery: Int, color: String, done: Bool)] {
        TopicTree.all.flatMap { subject in
            subject.subtopics.map { sub in
                (
                    subject.label, sub.label, sub.mathTopics.first ?? .arithmetic,
                    Int(store.stats.mastery(for: sub.mathTopics.first ?? .arithmetic).rounded()),
                    subject.color,
                    store.stats.lessonsCompleted.contains(sub.key)
                )
            }
        }
        .sorted { $0.mastery > $1.mastery }
    }

    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(
                badgeText: "📊 Statistics",
                badgeTone: .blue,
                title: "Your statistics",
                subtitle: "A detailed look at your math practice over time."
            )

            let wrong = store.stats.totalAnswered - store.stats.totalCorrect
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(icon: "target", tone: .blue, label: "Answered", value: "\(store.stats.totalAnswered)")
                statCard(icon: "checkmark.circle.fill", tone: .mint, label: "Correct", value: "\(store.stats.totalCorrect)")
                statCard(icon: "xmark.circle.fill", tone: .coral, label: "Incorrect", value: "\(wrong)")
                statCard(icon: "bolt.fill", tone: .yellow, label: "Accuracy", value: "\(store.stats.accuracy)%")
                statCard(icon: "book.fill", tone: .mint, label: "Lessons done", value: "\(store.stats.lessonsCompleted.count)")
                statCard(icon: "star.fill", tone: .purple, label: "Level", value: "\(store.stats.level)")
            }

            // Per-topic mastery table
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    StickerBadge(text: "Per-topic mastery", tone: MLColor.mint, foreground: MLColor.ink)
                    Spacer()
                    Text("\(topicRows.count) topics · sorted by mastery")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    ForEach(Array(topicRows.enumerated()), id: \.element.label) { i, row in
                        HStack(spacing: 10) {
                            Text(row.done ? "✓" : "\(i + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 26, height: 26)
                                .background(Tone(rawValue: row.color)?.bg.opacity(0.4) ?? MLColor.cream)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(MLColor.ink)
                                Text(row.subject)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            StickerProgress(value: Double(row.mastery), tone: Tone(rawValue: row.color) ?? .mint)
                                .frame(width: 86)
                            Text("\(row.mastery)%")
                                .font(.system(size: 13, weight: .bold))
                                .monospacedDigit()
                                .frame(width: 38, alignment: .trailing)
                                .foregroundStyle(MLColor.ink)
                        }
                        .padding(.vertical, 8)
                        if i < topicRows.count - 1 {
                            Rectangle().fill(MLColor.ink.opacity(0.07)).frame(height: 1)
                        }
                    }
                }
            }
            .padding(14)
            .stickerCard(radius: 18, lift: 4)

            if store.stats.totalAnswered == 0 {
                VStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(MLColor.ink)
                    Text("No data yet")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(MLColor.ink)
                    Text("Answer some questions to fill in your statistics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(22)
                .background(MLColor.cream) // calm sage-tinted panel (matches web --muted)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(MLColor.ink.opacity(0.10), lineWidth: 1))
                .shadow(color: MLColor.ink.opacity(0.06), radius: 8, x: 0, y: 3)
            }
        }
    }

    private func statCard(icon: String, tone: Tone, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tone.fg)
                .frame(width: 40, height: 40)
                .background(tone.bg.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(MLColor.ink)
            }
            Spacer()
        }
        .padding(12)
        .stickerCard(radius: 16, lift: 3)
    }
}

// MARK: - Achievements (12-badge gallery)

private struct AchievementsView: View {
    @EnvironmentObject private var store: StudyStore

    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(
                badgeText: "🏆 Achievements",
                badgeTone: .yellow,
                title: "Achievements",
                subtitle: "\(unlocked) of \(AchievementDef.all.count) unlocked — keep practicing to earn them all."
            )

            // Summary bar
            HStack {
                summaryCell(count: unlocked, label: "Unlocked", sub: "\(percentComplete)% complete", tint: MLColor.yellow)
                Spacer()
                summaryCell(count: AchievementDef.all.count - unlocked, label: "Locked", sub: "Still to earn", tint: nil)
            }
            .padding(14)
            .stickerCard(radius: 18, lift: 4)

            // Badge grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(AchievementDef.all) { def in
                    badgeCard(def)
                }
            }
        }
    }

    private var unlocked: Int {
        AchievementDef.all.filter { $0.isUnlocked(store.stats) }.count
    }

    private var percentComplete: Int {
        Int(Double(unlocked) / Double(AchievementDef.all.count) * 100)
    }

    private func summaryCell(count: Int, label: String, sub: String, tint: Color?) -> some View {
        HStack(spacing: 10) {
            Text("\(count)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint == nil ? MLColor.ink.opacity(0.5) : MLColor.ink)
                .frame(width: 42, height: 42)
                .background(tint ?? MLColor.cream)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(MLColor.ink.opacity(0.2), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MLColor.ink)
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func badgeCard(_ def: AchievementDef) -> some View {
        let done = def.isUnlocked(store.stats)
        let progress = def.progress(store.stats)
        let pct = progress.target > 0 ? Double(progress.current) / Double(progress.target) * 100 : 0
        return VStack(spacing: 6) {
            ZStack {
                if done {
                    Text(def.emoji)
                        .font(.system(size: 26))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 50, height: 50)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MLColor.ink.opacity(0.25), lineWidth: 1.5))

            Text(def.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(done ? MLColor.ink : MLColor.ink.opacity(0.75))
                .multilineTextAlignment(.center)
            Text(def.description)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(done ? MLColor.ink.opacity(0.8) : .secondary)
                .multilineTextAlignment(.center)

            if done {
                Label("Unlocked", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MLColor.ink)
            } else {
                StickerProgress(value: pct, tone: def.tone, height: 6)
                Text("\(progress.current) / \(progress.target)")
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(done ? def.tone.bg.opacity(0.85) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MLColor.ink, lineWidth: 2))
        .shadow(color: MLColor.ink.opacity(0.8), radius: 0, x: 0, y: 3)
    }
}
