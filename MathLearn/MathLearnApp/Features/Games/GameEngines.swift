//
//  GameEngines.swift
//  MathLearn
//
//  The three Swift-native game loops (boss-system port):
//   • BossBattleGame — answer to damage the boss (5 HP); wrong answers
//     cost a heart (3 HP). Combo bonus XP every third hit.
//   • SpeedDrillGame — 60-second rapid-fire round.
//   • EquationMatchGame — pair equations with solutions against a clock.
//  All three finish into the shared ResultsCard via QuizResultData.
//

import SwiftUI

// MARK: - Boss Battle

struct BossBattleGame: View {
    @EnvironmentObject private var store: StudyStore
    let difficulty: MathDifficulty
    let onFinish: (QuizResultData) -> Void

    @State private var bossHP = 5
    @State private var playerHP = 3
    @State private var question: MathQuestion?
    @State private var status: AnswerStatus = .unanswered
    @State private var combo = 0
    @State private var answered = 0
    @State private var correct = 0
    @State private var xpEarned = 0
    @State private var startedAt = Date()
    @State private var shakeWrong = false

    private let bossNames = ["The Fraction Dragon", "Count Calculus", "Algebra Golem", "The Median Monster"]

    var body: some View {
        VStack(spacing: 16) {
            // Battle status board
            VStack(spacing: 10) {
                HStack {
                    Text("🐲 \(bossName)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < playerHP ? "heart.fill" : "heart")
                                .foregroundStyle(i < playerHP ? Color.white : Color.white.opacity(0.35))
                        }
                    }
                }
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(i < bossHP ? MLColor.yellow : Color.white.opacity(0.25))
                            .frame(height: 10)
                    }
                }
                if combo > 0 {
                    Text("🔥 \(combo) combo — bonus XP on 3!")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(MLColor.yellow)
                }
            }
            .padding(14)
            .background(MLColor.ink)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let question {
                QuestionCardView(
                    question: question,
                    index: answered,
                    total: max(answered + 2, 2),
                    status: status,
                    onAnswer: answer,
                    onNext: next
                )
            }
        }
        .modifier(ShakeEffect(shakes: shakeWrong ? 3 : 0))
        .onAppear { draw() }
    }

    @State private var bossName = "The Fraction Dragon"

    private func draw() {
        bossName = bossNames.randomElement()!
        question = QuestionGenerator.generateQuestion(
            topic: MathTopic.allCases.randomElement() ?? .arithmetic,
            difficulty: difficulty
        )
        status = .unanswered
    }

    private func answer(_ value: String) {
        guard let question, status == .unanswered else { return }
        let ok = value == question.answer
        status = .answered(selected: value, correct: ok)
        answered += 1
        store.recordAnswer(topic: question.topic, difficulty: difficulty, correct: ok)
        if ok {
            correct += 1
            combo += 1
            bossHP -= 1
            let bonus = combo % 3 == 0 ? 20 : 0
            xpEarned += difficulty.xpMultiplier + bonus
            if bossHP <= 0 {
                let win = QuizResultData(
                    score: correct, total: max(answered, 1),
                    xpEarned: xpEarned + 50,
                    durationSec: Int(Date().timeIntervalSince(startedAt))
                )
                finish(win)
            }
        } else {
            combo = 0
            playerHP -= 1
            store.trackMistake(question: question, userAnswer: value)
            withAnimation(.default) { shakeWrong = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shakeWrong = false }
            if playerHP <= 0 {
                finish(QuizResultData(
                    score: correct, total: max(answered, 1),
                    xpEarned: xpEarned,
                    durationSec: Int(Date().timeIntervalSince(startedAt))
                ))
            }
        }
    }

    private func next() {
        if playerHP > 0 && bossHP > 0 { draw() }
    }

    private func finish(_ result: QuizResultData) {
        onFinish(result)
    }
}

// MARK: - Speed Drill

struct SpeedDrillGame: View {
    @EnvironmentObject private var store: StudyStore
    let difficulty: MathDifficulty
    let onFinish: (QuizResultData) -> Void

    @State private var secondsLeft = 60
    @State private var question: MathQuestion?
    @State private var status: AnswerStatus = .unanswered
    @State private var answered = 0
    @State private var correct = 0
    @State private var xpEarned = 0
    @State private var bestStreak = 0
    @State private var streak = 0
    @State private var timer: Timer?
    @State private var startedAt = Date()

    var body: some View {
        VStack(spacing: 16) {
            // Clock
            HStack {
                Label("\(secondsLeft)s", systemImage: "clock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(secondsLeft <= 10 ? MLColor.coral : MLColor.ink)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("✓ \(correct)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(MLColor.mintStrong)
                    Text("streak \(streak) · best \(bestStreak)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)

            if let question {
                QuestionCardView(
                    question: question,
                    index: answered,
                    total: max(answered + 2, 2),
                    status: status,
                    onAnswer: answer,
                    onNext: next,
                    nextLabel: "Skip → Next"
                )
            }
        }
        .onAppear {
            draw()
            startedAt = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
                Task { @MainActor in
                    secondsLeft -= 1
                    if secondsLeft <= 0 {
                        t.invalidate()
                        finish()
                    }
                }
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    private func draw() {
        question = QuestionGenerator.generateQuestion(
            topic: MathTopic.allCases.randomElement() ?? .arithmetic,
            difficulty: difficulty
        )
        status = .unanswered
    }

    private func answer(_ value: String) {
        guard let question, status == .unanswered else { return }
        let ok = value == question.answer
        status = .answered(selected: value, correct: ok)
        answered += 1
        store.recordAnswer(topic: question.topic, difficulty: difficulty, correct: ok)
        if ok {
            correct += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            xpEarned += difficulty.xpMultiplier
        } else {
            streak = 0
            store.trackMistake(question: question, userAnswer: value)
        }
    }

    private func next() {
        draw()
    }

    private func finish() {
        timer?.invalidate()
        onFinish(QuizResultData(
            score: correct, total: max(answered, 1),
            xpEarned: xpEarned,
            durationSec: 60 - max(0, secondsLeft)
        ))
    }
}

// MARK: - Equation Match

struct EquationMatchGame: View {
    @EnvironmentObject private var store: StudyStore
    let difficulty: MathDifficulty
    let onFinish: (QuizResultData) -> Void

    struct Tile: Identifiable, Equatable {
        let id: Int
        let text: String
        let pairID: Int     // matching pair group
        let isEquation: Bool
    }

    @State private var tiles: [Tile] = []
    @State private var selectedEquation: Tile?
    @State private var matched: Set<Int> = []
    @State private var wrongFlash: Tile?
    @State private var misses = 0
    @State private var startedAt = Date()
    @State private var done = false

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Tap an equation, then its solution")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("misses \(misses)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MLColor.coral)
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(tiles) { tile in
                    tileButton(tile)
                }
            }
        }
        .onAppear { build() }
    }

    private func tileButton(_ tile: Tile) -> some View {
        let isMatched = matched.contains(tile.pairID)
        let isSelected = selectedEquation?.id == tile.id
        let isWrong = wrongFlash?.id == tile.id
        return Button {
            tap(tile)
        } label: {
            Text(tile.text)
                .font(.system(size: tile.isEquation ? 15 : 16, weight: .semibold))
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 74)
                .padding(10)
                .background(
                    isMatched ? MLColor.mint.opacity(0.35)
                    : isWrong ? MLColor.coral
                    : isSelected ? MLColor.yellow
                    : Color.white
                )
                .foregroundStyle(isWrong ? .white : MLColor.ink)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MLColor.ink, lineWidth: 2))
                .shadow(color: MLColor.ink.opacity(0.7), radius: 0, x: 0, y: 3)
        }
        .disabled(isMatched || done)
        .opacity(isMatched ? 0.35 : 1)
        .animation(.easeOut(duration: 0.15), value: isMatched)
    }

    private func build() {
        // Three fresh equations + their solutions.
        var equations: [(eq: String, sol: String)] = []
        var used = Set<String>()
        while equations.count < 3 {
            let q = QuestionGenerator.generateQuestion(topic: .preAlgebra, difficulty: difficulty)
            guard !used.contains(q.question) else { continue }
            used.insert(q.question)
            equations.append((q.question, q.answer))
        }
        var id = 0
        var built: [Tile] = []
        for (i, pair) in equations.enumerated() {
            built.append(Tile(id: id, text: pair.eq, pairID: 100 + i, isEquation: true)); id += 1
        }
        for (i, pair) in equations.enumerated() {
            built.append(Tile(id: id, text: pair.sol, pairID: 100 + i, isEquation: false)); id += 1
        }
        tiles = built.shuffled()
        selectedEquation = nil
        matched = []
        misses = 0
        startedAt = Date()
        done = false
    }

    private func tap(_ tile: Tile) {
        if let sel = selectedEquation {
            if sel.id == tile.id {
                selectedEquation = nil
                return
            }
            if sel.isEquation == tile.isEquation {
                // Same kind — switch selection.
                selectedEquation = tile
                return
            }
            let equation = sel.isEquation ? sel : tile
            let solution = sel.isEquation ? tile : sel
            if equation.pairID == solution.pairID {
                matched.insert(equation.pairID)
                store.recordAnswer(topic: .preAlgebra, difficulty: difficulty, correct: true)
                selectedEquation = nil
                if matched.count == 3 {
                    done = true
                    let sec = Int(Date().timeIntervalSince(startedAt))
                    let score = max(1, 3 - min(2, misses / 2))
                    onFinish(QuizResultData(
                        score: score, total: 3,
                        xpEarned: 30 + max(0, 30 - sec / 2) + max(0, 10 - misses * 3),
                        durationSec: sec
                    ))
                }
            } else {
                misses += 1
                wrongFlash = solution
                selectedEquation = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { wrongFlash = nil }
            }
        } else {
            selectedEquation = tile
        }
    }
}

// MARK: - Shake effect (wrong answer feedback)

struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: shakes == 0 ? 0 : sin(shakes * .pi * 6) * 8 * (1 - shakes),
            y: 0
        ))
    }
}
