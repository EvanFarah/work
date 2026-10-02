//
//  HomeView.swift
//  MathLearn
//
//  Port of DashboardView.tsx — the actionable home dashboard:
//   1. "Jump Back In" hero card (resume last lesson)
//   2. Compact 3-column stats bar (XP · Streak · Mastery)
//   3. 2x3 feature navigation grid
//   4. Scannable "Explore All Levels" browse preview
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var catalog: CatalogService

    var body: some View {
        NavigationStack {
            ZStack {
                MLColor.cream.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        jumpBackIn
                        statsBar
                        featureGrid
                        exploreLevels
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { MoreToolbarButton() } }
        }
    }

    // MARK: 1. Jump Back In

    private var resumeTarget: (course: CourseIndexEntry, lesson: IndexLesson, unit: String)? {
        guard let last = store.stats.lastStudied,
              let course = catalog.entry(for: last.courseSlug) else { return nil }
        for unit in course.units {
            if let lesson = unit.lessons.first(where: { LessonDocument.slugify($0.title) == last.lessonSlug }) {
                return (course, lesson, unit.name)
            }
        }
        if let first = course.units.first?.lessons.first {
            return (course, first, course.units.first?.name ?? "")
        }
        return nil
    }

    private var jumpBackIn: some View {
        let hasHistory = store.stats.lastStudied != nil
        let target = resumeTarget
        let title = hasHistory
            ? (store.stats.lastStudied?.lessonTitle ?? target?.lesson.title ?? "Your first lesson")
            : (target?.lesson.title ?? "Your first lesson")
        let courseLabel = hasHistory
            ? (target?.course.name ?? store.stats.lastStudied?.courseLabel ?? "1st Grade Math")
            : (target?.course.name ?? "1st Grade Math")
        let topic = store.stats.lastStudied?.topic ?? target?.course.mathTopic ?? .arithmetic
        let topicMastery = Int(store.stats.mastery(for: topic).rounded())
        let nextGoal = hasHistory ? "Next: Level \(store.stats.level + 1)" : "Next: First lesson"
        let stage = store.stats.lastStudied?.stage ?? "learn"
        let sentence = hasHistory
            ? "\(courseLabel) · \(Self.stageSentence(stage))"
            : "Kick off with “\(title)” in \(courseLabel) — bite-sized and beginner friendly."

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                StickerBadge(text: "Jump Back In", tone: MLColor.coral, foreground: .white)
                Spacer(minLength: 6)
                StickerBadge(text: "🎯 \(nextGoal)")
            }
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(MLColor.ink)
                .padding(.top, 12)
                .fixedSize(horizontal: false, vertical: true)
            Text(sentence)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("MASTERY")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(topicMastery)%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MLColor.ink)
                }
                StickerProgress(value: Double(topicMastery), tone: .mint)
            }
            .padding(.top, 14)

            NavigationLink {
                destination(for: target)
            } label: {
                Label(hasHistory ? "Resume Lesson" : "Start Learning", systemImage: "play.fill")
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.stickerCoral)
            .padding(.top, 16)
        }
        .padding(18)
        .stickerCard()
    }

    private static func stageSentence(_ stage: String) -> String {
        switch stage {
        case "practice": return "You were mid-practice — a few more reps to lock it in."
        case "quiz": return "Your quiz is queued up — finish it to bank the XP."
        case "results": return "Nice work on that quiz — the next lesson is one tap away."
        default: return "You left off at the Learn step — pick up right where you stopped."
        }
    }

    @ViewBuilder
    private func destination(for target: (course: CourseIndexEntry, lesson: IndexLesson, unit: String)?) -> some View {
        if let target {
            LessonPlayerView(course: target.course, unitName: target.unit, lessonTitle: target.lesson.title)
        } else {
            ModulesView()
        }
    }

    // MARK: 2. Stats bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            StatTile(icon: "bolt.fill", tone: .yellow, label: "Total XP", value: "\(store.stats.xp)", sub: "Level \(store.stats.level)")
            divider
            StatTile(icon: "flame.fill", tone: .coral, label: "Day Streak", value: "\(store.stats.streakDays)", sub: store.stats.streakDays == 1 ? "day in a row" : "days in a row")
            divider
            StatTile(icon: "gauge.high", tone: .mint, label: "Mastery", value: "\(store.stats.overallMastery)%", sub: "all topics")
        }
        .padding(.vertical, 14)
        .stickerCard(radius: 20, lift: 5)
    }

    private var divider: some View {
        Rectangle()
            .fill(MLColor.ink.opacity(0.1))
            .frame(width: 1.5, height: 56)
    }

    // MARK: 3. Feature grid

    private var featureGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            featureTile(icon: "target", label: "Practice Drills", desc: "Adaptive practice with instant feedback", tone: .coral) {
                switchTabToPractice(initialTab: .practice)
            }
            featureTile(icon: "timer", label: "Timed Quizzes", desc: "Race the clock on custom quizzes", tone: .blue) {
                switchTabToPractice(initialTab: .quizzes)
            }
            featureTile(icon: "gamecontroller.fill", label: "Math Games", desc: "Play quick games and earn XP", tone: .purple) {
                switchTabToPractice(initialTab: .games)
            }
            featureTile(icon: "bubble.left.and.text.bubble.right.fill", label: "AI Tutor", desc: "Ask anything — step-by-step help", tone: .mint) {
                switchTab(.tutor)
            }
            featureTile(icon: "chart.bar.fill", label: "Performance Stats", desc: "Accuracy, XP history and mastery", tone: .yellow) {
                switchTab(.progress)
            }
            featureTile(icon: "trophy.fill", label: "Achievements", desc: "Badges and goals to conquer", tone: .white) {
                switchTab(.progress)
            }
        }
    }

    private func featureTile(icon: String, label: String, desc: String, tone: Tone, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tone == .white ? MLColor.coral : tone.fg)
                    .frame(width: 40, height: 40)
                    .background(tone == .white ? MLColor.cream : tone.bg.opacity(0.24))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MLColor.ink)
                    .multilineTextAlignment(.leading)
                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .stickerCard(radius: 18, lift: 4)
        }
    }

    // MARK: 4. Explore All Levels

    private var exploreLevels: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Explore All Levels")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                Spacer()
                NavigationLink {
                    ModulesView()
                } label: {
                    HStack(spacing: 2) {
                        Text("All \(catalog.courses.count) levels")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(catalog.courses.prefix(6).enumerated()), id: \.element.id) { index, course in
                    NavigationLink {
                        CourseDetailView(course: course)
                    } label: {
                        HStack(spacing: 12) {
                            Text(course.icon)
                                .font(.system(size: 16))
                                .frame(width: 36, height: 36)
                                .background(Color(red: course.accentColor.red, green: course.accentColor.green, blue: course.accentColor.blue))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(course.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(MLColor.ink)
                                    .lineLimit(1)
                                Text("\(course.lessonCount) lessons · \(course.gradeBand)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                    }
                    if index < 5 {
                        Rectangle().fill(MLColor.ink.opacity(0.07)).frame(height: 1)
                    }
                }
            }
            .padding(6)
            .stickerCard(radius: 18, lift: 4)
        }
    }

    // MARK: - Cross-tab navigation helper

    private func switchTabToPractice(initialTab: PracticeTab) {
        NotificationCenter.default.post(
            name: .mlPracticeTabRequest, object: nil,
            userInfo: ["tab": initialTab]
        )
        switchTab(.practice)
    }

    private func switchTab(_ tab: MainTab) {
        NotificationCenter.default.post(name: .mlMainTabRequest, object: nil, userInfo: ["tab": tab])
    }
}

// MARK: - Tab routing (dashboard deep-links into tabs)

enum MainTab: Hashable {
    case home, practice, lessons, tutor, progress
}

enum PracticeTab: String, Hashable {
    case practice, quizzes, games, courses
}

extension Notification.Name {
    static let mlMainTabRequest = Notification.Name("ml.mainTabRequest")
    static let mlPracticeTabRequest = Notification.Name("ml.practiceTabRequest")
}
