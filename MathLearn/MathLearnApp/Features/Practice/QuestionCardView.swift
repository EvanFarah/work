//
//  QuestionCardView.swift
//  MathLearn
//
//  Port of QuestionCard.tsx — shared question display. Sticker-styled
//  option cards with hairline borders, soft shadows, and color fills
//  for correct (mint) / wrong (sage-coral). Every question also carries
//  an AUTO-LEARN strip: the hint surfaces itself as teaching (the
//  method is on the card before the first tap — no hint button), and
//  timed quizzes opt out so assessment stays honest.
//

import SwiftUI

enum AnswerStatus: Equatable {
    case unanswered
    case answered(selected: String, correct: Bool)
    case locked(selected: String?)

    var isAnswered: Bool {
        if case .unanswered = self { return false }
        return true
    }
}

struct QuestionCardView: View {
    let question: MathQuestion
    let index: Int
    let total: Int
    let status: AnswerStatus
    var timeLeft: Int? = nil
    var onAnswer: (String) -> Void
    var onNext: (() -> Void)? = nil
    var nextLabel: String = "Next"
    var hideExplanation: Bool = false
    /// Auto-learning: show the question's hint as an always-visible
    /// "method" strip. Timed quizzes pass false — assessment first.
    var showsAutoLearn: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Progress + timer row
            HStack(spacing: 12) {
                ProgressView(value: total > 0 ? Double(index) / Double(total) : 0)
                    .tint(MLColor.blue)
                if let timeLeft {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                        Text("\(timeLeft)s")
                            .monospacedDigit()
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(timeLeft <= 5 ? Color.white : MLColor.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(timeLeft <= 5 ? MLColor.coral : MLColor.yellow)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(MLColor.ink.opacity(0.2), lineWidth: 1.5))
                    // Snappy color crossfade when the pill flips to urgent
                    // (yellow → coral ≤5s). Solid surface — never glass.
                    .animation(MLMotion.selection, value: timeLeft <= 5)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                // Meta row
                HStack(spacing: 8) {
                    StickerBadge(text: question.topic.label, tone: MLColor.purple, foreground: .white)
                    StickerBadge(text: question.difficulty.rawValue, tone: .white)
                    Spacer()
                    Text("Question \(index + 1) of \(total)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                // Prompt
                Text(question.question)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(MLColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                // Auto-learn — the hint IS the lesson: surfaced automatically,
                // before any tap, so every question teaches its method.
                if showsAutoLearn {
                    learnStrip
                        .transition(.opacity)
                }

                // Options
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { i, option in
                        OptionButton(
                            option: option,
                            letter: String(UnicodeScalar(65 + i) ?? "?"),
                            isCorrect: status.isAnswered && option == question.answer,
                            isSelectedWrong: isWrongSelected(option),
                            answered: status.isAnswered
                        ) {
                            if !status.isAnswered { onAnswer(option) }
                        }
                    }
                }

                // Feedback
                if showFeedback {
                    feedbackBox
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Next button
                if status.isAnswered, let onNext {
                    Button(action: onNext) {
                        Text(nextLabel)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.stickerCoral)
                    .padding(.top, 4)
                }
            }
            .padding(18)
            .stickerCard()
            .animation(.easeOut(duration: 0.2), value: status)
        }
    }

    private var isCorrectNow: Bool {
        if case .answered(_, let correct) = status { return correct }
        return false
    }

    private var showFeedback: Bool {
        if case .answered = status { return !hideExplanation }
        return false
    }

    private func isWrongSelected(_ option: String) -> Bool {
        switch status {
        case .answered(let selected, let correct):
            return selected == option && !correct
        case .locked(let selected):
            return selected == option && option != question.answer
        case .unanswered:
            return false
        }
    }

    private var feedbackBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isCorrectNow ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 17, weight: .bold))
            VStack(alignment: .leading, spacing: 4) {
                Text(isCorrectNow ? "Correct!" : "Not quite")
                    .font(.system(size: 16, weight: .bold))
                Text(question.explanation)
                    .font(.footnote)
                    .opacity(0.95)
                if !isCorrectNow {
                    // Reinforce the method on a miss (also covers timed
                    // quizzes, where the auto-learn strip is hidden).
                    Label(question.hint, systemImage: "graduationcap.fill")
                        .font(.caption.weight(.semibold))
                        .opacity(0.92)
                    Text("Answer: \(question.answer)")
                        .font(.footnote.weight(.heavy))
                }
            }
        }
        .foregroundStyle(isCorrectNow ? MLColor.ink : .white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCorrectNow ? MLColor.mint : MLColor.coral)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Auto-learn strip (hint → teaching)

    private var learnStrip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MLColor.mintStrong)
                .frame(width: 28, height: 28)
                .background(MLColor.mint.opacity(0.25))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("THE METHOD")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(MLColor.mintStrong)
                Text(question.hint)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(MLColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MLColor.mint.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(MLColor.mintStrong.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Method: \(question.hint)")
    }
}

// MARK: - Option button

private struct OptionButton: View {
    let option: String
    let letter: String
    let isCorrect: Bool
    let isSelectedWrong: Bool
    let answered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(letter)
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 30, height: 30)
                    .background(
                        answered && (isCorrect || isSelectedWrong)
                            ? Color.white
                            : MLColor.cream
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(option)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(foreground)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if answered && isCorrect {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                }
                if isSelectedWrong {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(MLColor.ink, lineWidth: 2)
            )
            .shadow(color: MLColor.ink.opacity(0.8), radius: 0, x: 0, y: 3)
        }
        .disabled(answered)
    }

    private var background: Color {
        if answered && isCorrect { return MLColor.mint }
        if isSelectedWrong { return MLColor.coral }
        return Color.white
    }

    private var foreground: Color {
        if isSelectedWrong { return .white }
        if answered && !isCorrect && !isSelectedWrong { return MLColor.ink.opacity(0.45) }
        return MLColor.ink
    }
}
