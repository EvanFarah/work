//
//  PracticeView.swift
//  MathLearn
//
//  Port of PracticeView.tsx — endless adaptive drills. Pick a subject
//  and subtopic, then drill questions with instant feedback; the
//  difficulty adapts live (3 correct → harder, 2 wrong → easier)
//  with a streak-flame indicator, exactly like the web practice stage.
//

import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Mode { case pick, drill }
    @State private var mode: Mode = .pick
    @State private var selection: StudySelection?
    @State private var question: MathQuestion?
    @State private var status: AnswerStatus = .unanswered
    @State private var streak = 0
    @State private var wrongStreak = 0
    @State private var answeredCount = 0
    @State private var correctCount = 0
    @State private var xpEarned = 0

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    switch mode {
                    case .pick:
                        picker
                            .transition(MLMotion.phaseTransition(reduceMotion: reduceMotion))
                    case .drill:
                        drill
                            .transition(MLMotion.phaseTransition(reduceMotion: reduceMotion))
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Picker (subject → subtopic)

    private var picker: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                badgeText: "⚡ Practice",
                badgeTone: .coral,
                title: "Adaptive Drills",
                subtitle: "Endless practice with instant feedback — 3 correct → harder, 2 wrong → easier."
            )
            ForEach(TopicTree.all) { subject in
                DisclosureGroup {
                    VStack(spacing: 8) {
                        ForEach(subject.subtopics) { sub in
                            Button {
                                start(subject: subject, subtopic: sub)
                            } label: {
                                HStack {
                                    Text(sub.label)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(MLColor.ink)
                                    Spacer()
                                    masteryPill(subject: subject, sub: sub)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(MLColor.cream)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    HStack(spacing: 12) {
                        Text(subject.icon)
                            .font(.system(size: 18))
                            .frame(width: 40, height: 40)
                            .background(Tone(rawValue: subject.color)?.bg ?? MLColor.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(subject.label)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(MLColor.ink)
                            Text(subject.blurb)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)
                .stickerCard(radius: 18, lift: 4)
                .tint(MLColor.ink)
            }
        }
    }

    private func masteryPill(subject: TopicInfo, sub: SubtopicInfo) -> some View {
        let m = Int(store.stats.mastery(for: sub.mathTopics.first ?? .arithmetic).rounded())
        return Text("\(m)%")
            .font(.caption2.weight(.heavy))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Tone(rawValue: subject.color)?.bg.opacity(0.3) ?? MLColor.cream)
            .foregroundStyle(MLColor.ink)
            .clipShape(Capsule())
    }

    // MARK: - Drill session

    private var drill: some View {
        VStack(spacing: 16) {
            // Session header
            HStack(spacing: 12) {
                Button {
                    withAnimation(reduceMotion ? MLMotion.crossfade : MLMotion.selection) {
                        mode = .pick
                    }
                    question = nil
                    status = .unanswered
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
                }
                .accessibilityLabel("Back to topics")

                VStack(alignment: .leading, spacing: 1) {
                    Text(selection?.subtopicLabel ?? "")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MLColor.ink)
                    Text("\(correctCount)/\(answeredCount) correct · +\(xpEarned) XP")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Spacer()
                // Streak flame (3-up / 2-down rule indicator) — bounces on
                // every correct answer (correctCount only ever increases).
                HStack(spacing: 3) {
                    Image(systemName: streak >= 3 ? "flame.fill" : "flame")
                        .foregroundStyle(streak >= 3 ? MLColor.coral : .secondary)
                        .symbolEffect(.bounce, value: correctCount)
                    Text("\(streak)")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(MLColor.ink)
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(streak >= 3 ? MLColor.yellow : Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
                .animation(MLMotion.adaptive(MLMotion.selection, reduceMotion: reduceMotion), value: answeredCount)
            }

            // Difficulty chip (live adaptive level)
            if let selection {
                HStack(spacing: 8) {
                    StickerBadge(
                        text: "Level: \(selection.difficulty.rawValue)",
                        tone: MLColor.blue, foreground: MLColor.ink
                    )
                    Text("adapted live")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            if let question {
                QuestionCardView(
                    question: question,
                    index: answeredCount,
                    total: max(answeredCount + 6, 6),
                    status: status,
                    onAnswer: answer,
                    onNext: next,
                    nextLabel: "Next Question"
                )
            } else {
                ProgressView("Loading question…")
                    .padding(40)
            }
        }
    }

    // MARK: - Engine (adaptive 3-up / 2-down)

    private func start(subject: TopicInfo, subtopic: SubtopicInfo) {
        let diff: MathDifficulty = {
            let m = store.stats.mastery(for: subtopic.mathTopics.first ?? .arithmetic)
            if m >= 70 { return .hard }
            if m >= 35 { return .medium }
            return .easy
        }()
        let sel = StudySelection(
            subjectKey: subject.key,
            subjectLabel: subject.label,
            subtopicKey: subtopic.key,
            subtopicLabel: subtopic.label,
            topic: subtopic.mathTopics.first ?? .arithmetic,
            difficulty: diff
        )
        selection = sel
        streak = 0
        wrongStreak = 0
        answeredCount = 0
        correctCount = 0
        xpEarned = 0
        drawQuestion()
        // M3 — animation context outside the phase conditional; crossfade
        // under Reduce Motion.
        withAnimation(reduceMotion ? MLMotion.crossfade : MLMotion.selection) {
            mode = .drill
        }
        store.setLastStudied(
            courseSlug: subject.key, courseLabel: subject.label,
            lessonTitle: subtopic.label, topic: sel.topic, stage: "practice"
        )
    }

    private func drawQuestion() {
        guard let selection else { return }
        let subtopic: String? = subtopicBranch(selection)
        question = QuestionGenerator.generateQuestion(
            topic: selection.topic,
            difficulty: selection.difficulty,
            subtopic: subtopic
        )
        status = .unanswered
    }

    /// Generators with dedicated subtopic branches honor the picker;
    /// single-branch topics pass nil.
    private func subtopicBranch(_ selection: StudySelection) -> String? {
        switch selection.topic {
        case .arithmetic:
            return ["addition", "subtraction", "multiplication", "division"].contains(selection.subtopicKey)
                ? selection.subtopicKey : nil
        case .algebra1, .algebra2, .geometry, .trigonometry, .precalculus, .calculus, .statistics:
            return selection.subtopicKey
        default:
            return nil
        }
    }

    private func answer(_ value: String) {
        guard let question, status == .unanswered, let selection else { return }
        let correct = value == question.answer
        status = .answered(selected: value, correct: correct)
        answeredCount += 1
        store.recordAnswer(topic: question.topic, difficulty: selection.difficulty, correct: correct)
        if correct {
            correctCount += 1
            xpEarned += selection.difficulty.xpMultiplier
            streak += 1
            wrongStreak = 0
            if streak >= 3 {
                selection?.difficulty = selection?.difficulty.next ?? selection?.difficulty ?? .medium
                streak = 0
            }
        } else {
            streak = 0
            wrongStreak += 1
            store.trackMistake(question: question, userAnswer: value)
            if wrongStreak >= 2 {
                selection?.difficulty = selection?.difficulty.previous ?? selection?.difficulty ?? .easy
                wrongStreak = 0
            }
        }
    }

    private func next() {
        drawQuestion()
    }
}
