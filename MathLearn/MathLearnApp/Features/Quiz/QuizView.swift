//
//  QuizView.swift
//  MathLearn
//
//  Port of the quiz loop (QuizStage/QuestionCard, phase 1 shell):
//  question card → choice tap → instant feedback with explanation →
//  next. Adaptive difficulty (3 correct → harder, 2 wrong → easier)
//  plugs into the backend quiz API in the data-layer phase.
//

import SwiftUI

struct QuizView: View {
    @State private var session = QuizSession(
        topic: "Linear Equations",
        questions: [
            QuizQuestion(id: .init(), prompt: "Solve: 2x + 3 = 11", choices: ["x = 3", "x = 4", "x = 5", "x = 7"], correctIndex: 1, explanation: "Subtract 3 from both sides, then divide by 2: x = 4."),
            QuizQuestion(id: .init(), prompt: "12 × (−3) = ?", choices: ["36", "−36", "−15", "15"], correctIndex: 1, explanation: "A positive times a negative is negative: 12 × 3 = 36 → −36."),
            QuizQuestion(id: .init(), prompt: "Simplify: 3(x − 4) + 2x", choices: ["5x − 12", "5x − 4", "6x − 12", "x − 12"], correctIndex: 0, explanation: "Distribute 3 → 3x − 12, combine with 2x → 5x − 12."),
        ]
    )
    @State private var picked: Int?

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()

            if let q = session.current {
                VStack(alignment: .leading, spacing: 20) {
                    ProgressView(value: session.progress)
                        .tint(MLColor.coral)

                    Text(session.topic)
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    Text(q.prompt)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(MLColor.ink)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .stickerCard()

                    ForEach(q.choices.indices, id: \.self) { i in
                        choiceButton(q, index: i)
                    }

                    if let picked, picked != q.correctIndex {
                        Text(q.explanation)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(MLColor.ink)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(MLColor.yellow.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Spacer(minLength: 0)
                }
                .padding(20)
            } else {
                doneView
            }
        }
    }

    private func choiceButton(_ q: QuizQuestion, index: Int) -> some View {
        let isPicked = picked == index
        let reveal = picked != nil
        let isRight = index == q.correctIndex

        return Button {
            guard picked == nil else { return }
            picked = index
            _ = session.record(answerIndex: index)
        } label: {
            HStack {
                Text(q.choices[index])
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                Spacer()
                if reveal && isRight {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(MLColor.mintStrong)
                } else if isPicked && !isRight {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(MLColor.coral)
                }
            }
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(reveal && isRight ? MLColor.mint : (isPicked ? MLColor.coral : MLColor.ink.opacity(0.15)), lineWidth: 3)
            )
            .shadow(color: MLColor.ink.opacity(0.8), radius: 0, x: 0, y: 3)
        }
        .disabled(reveal)
    }

    private var doneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 42))
                .foregroundStyle(MLColor.coral)
            Text("Session complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(MLColor.ink)
            Text("\(session.correctCount) / \(session.questions.count) correct")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button {
                session = QuizSession(topic: session.topic, questions: session.questions)
                picked = nil
            } label: {
                Text("Practice again")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.stickerCoral)
            .padding(.horizontal, 40)
        }
    }
}
