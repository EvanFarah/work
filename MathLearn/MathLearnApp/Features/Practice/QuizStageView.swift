//
//  QuizStageView.swift
//  MathLearn
//
//  Port of QuizStage.tsx — a timed 6-question quiz: intro card →
//  per-question countdown (time out counts as wrong) → results with
//  XP banking. Reused by QuizzesView, QuizMakerView, and games.
//

import SwiftUI
import UIKit

struct QuizStageView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let selection: StudySelection
    var questionCount: Int = 6
    var onNewTopic: () -> Void

    private enum Phase { case intro, active, results }
    @State private var phase: Phase = .intro
    @State private var questions: [MathQuestion] = []
    @State private var index = 0
    @State private var answers: [Int: String] = [:]     // index → selected option
    @State private var timeLeft = 0
    @State private var startedAt: Date?
    @State private var result: QuizResultData?
    @State private var timer: Timer?

    private var current: MathQuestion? {
        questions.indices.contains(index) ? questions[index] : nil
    }

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    switch phase {
                    case .intro:
                        introCard
                            .transition(MLMotion.phaseTransition(reduceMotion: reduceMotion))
                    case .active:
                        activeQuiz
                            .transition(MLMotion.phaseTransition(reduceMotion: reduceMotion))
                    case .results:
                        if let result {
                            ResultsCardView(
                                result: result,
                                topicLabel: selection.subtopicLabel,
                                onRetry: retry,
                                onNewTopic: onNewTopic
                            )
                            .transition(MLMotion.phaseTransition(reduceMotion: reduceMotion))
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(selection.subjectLabel)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Intro (QuizStage.tsx intro card)

    private var introCard: some View {
        VStack(spacing: 14) {
            Text("🏆")
                .font(.system(size: 52))
                .frame(width: 70, height: 70)
                .background(MLColor.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .stickerCard(radius: 18, lift: 5)

            StickerBadge(text: "🏆 Quiz")
            Text("Ready for the Quiz?")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(MLColor.ink)
            Text("\(selection.subtopicLabel) · \(selection.difficulty.rawValue) difficulty")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                introStat(icon: "clock.fill", label: "Timed", value: "Per Q", tone: .blue)
                introStat(icon: "flag.fill", label: "Questions", value: "\(questionCount)", tone: .coral)
                introStat(icon: "textformat.123", label: "Level", value: selection.difficulty.rawValue.capitalized, tone: .purple)
            }
            .padding(.vertical, 6)

            Text("You'll have a time limit on each question. Answer all \(questionCount) to see your score and earn XP.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: beginQuiz) {
                Text("Start Quiz")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.stickerCoral)
        }
        .padding(22)
        .stickerCard()
    }

    private func introStat(icon: String, label: String, value: String, tone: Tone) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MLColor.ink)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .textCase(.capitalized)
                .foregroundStyle(MLColor.ink)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(MLColor.ink.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tone.bg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Active quiz

    private var activeQuiz: some View {
        VStack(spacing: 16) {
            // Top bar: exit, progress, answered count
            HStack(spacing: 12) {
                Button(action: onNewTopic) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
                }
                .accessibilityLabel("Exit quiz")

                ProgressView(value: Double(answers.count), total: Double(questions.count))
                    .tint(MLColor.yellow)

                Text("\(answers.count)/\(questions.count)")
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
            }

            if let current {
                QuestionCardView(
                    question: current,
                    index: index,
                    total: questions.count,
                    status: statusForCurrent,
                    timeLeft: timeLeft,
                    onAnswer: handleAnswer,
                    onNext: goNext,
                    nextLabel: index + 1 >= questions.count ? "Finish & See Results" : "Next Question",
                    hideExplanation: true,
                    // Timed quiz = assessment: no auto-learn strip. The
                    // method still teaches in the wrong-answer feedback.
                    showsAutoLearn: false
                )

                // Review bar after answering
                if statusForCurrent.isAnswered {
                    HStack {
                        Button {
                            guard index > 0 else { return }
                            index -= 1
                            timeLeft = questions[index].timeLimit
                        } label: {
                            Label("Previous", systemImage: "chevron.left")
                        }
                        .buttonStyle(.stickerWhite)
                        .disabled(index == 0)
                        .opacity(index == 0 ? 0.5 : 1)

                        Spacer()

                        Button {
                            goNext()
                        } label: {
                            Label("Next", systemImage: "chevron.right")
                        }
                        .buttonStyle(.stickerWhite)
                        .disabled(index + 1 >= questions.count)
                        .opacity(index + 1 >= questions.count ? 0.5 : 1)
                    }
                }
            }
        }
    }

    private var statusForCurrent: AnswerStatus {
        if let selected = answers[index] {
            return .locked(selected: selected)
        }
        return .unanswered
    }

    // MARK: - Engine

    private func beginQuiz() {
        questions = QuestionGenerator.generateQuestions(
            topic: selection.topic,
            difficulty: selection.difficulty,
            count: questionCount,
            subtopic: Self.subtopicBranch(selection)
        )
        index = 0
        answers = [:]
        timeLeft = questions.first?.timeLimit ?? 30
        startedAt = Date()
        // M3 — the animation context lives OUTSIDE the phase conditional
        // (the #1 silent-failure rule); Reduce Motion gets a crossfade.
        withAnimation(reduceMotion ? MLMotion.crossfade : MLMotion.selection) {
            phase = .active
        }
        startTimer()
    }

    /// Generators with dedicated subtopic branches honor the picker;
    /// single-branch topics pass nil (mirrors PracticeView).
    private static func subtopicBranch(_ selection: StudySelection) -> String? {
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

    private func startTimer() {
        timer?.invalidate()
        guard answers[index] == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            Task { @MainActor in
                if timeLeft <= 1 {
                    t.invalidate()
                    timeLeft = 0
                    // Time out → record as wrong (locked, no selection).
                    answers[index] = ""
                    store.recordAnswer(topic: current?.topic ?? selection.topic, difficulty: selection.difficulty, correct: false)
                } else {
                    timeLeft -= 1
                }
            }
        }
    }

    private func handleAnswer(_ value: String) {
        guard answers[index] == nil else { return }
        timer?.invalidate()
        answers[index] = value
        let q = current
        let correct = q.map { $0.answer == value } ?? false
        store.recordAnswer(topic: q?.topic ?? selection.topic, difficulty: selection.difficulty, correct: correct)
        if !correct, let q {
            store.trackMistake(question: q, userAnswer: value)
        }
    }

    private func goNext() {
        if index + 1 >= questions.count {
            finish()
            return
        }
        index += 1
        timeLeft = questions[index].timeLimit
        startTimer()
    }

    private func finish() {
        timer?.invalidate()
        var score = 0
        var xpEarned = 0
        for (i, q) in questions.enumerated() {
            if let a = answers[i], a == q.answer {
                score += 1
                xpEarned += q.difficulty.xpMultiplier
            }
        }
        let duration = Int(Date().timeIntervalSince(startedAt ?? Date()))
        result = QuizResultData(score: score, total: questions.count, xpEarned: xpEarned, durationSec: duration)
        store.recordAttempt(QuizAttempt(
            id: UUID().uuidString,
            label: selection.subtopicLabel,
            subject: selection.subjectLabel,
            topic: selection.topic,
            difficulty: selection.difficulty,
            score: score,
            total: questions.count,
            xpEarned: xpEarned,
            durationSec: duration,
            at: Date()
        ))
        store.setLastStudied(
            courseSlug: selection.subjectKey,
            courseLabel: selection.subjectLabel,
            lessonTitle: selection.subtopicLabel,
            topic: selection.topic,
            stage: "results"
        )
        withAnimation(reduceMotion ? MLMotion.crossfade : MLMotion.selection) {
            phase = .results
        }
    }

    private func retry() {
        beginQuiz()
    }
}
