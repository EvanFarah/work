//
//  ResultsCardView.swift
//  MathLearn
//
//  Port of ResultsCard.tsx — celebratory sticker hero with the big
//  grade badge, score/accuracy/time/XP stat tiles, and retry /
//  new-topic pill buttons. Confetti on S/A grades.
//

import SwiftUI

struct QuizResultData {
    var score: Int
    var total: Int
    var xpEarned: Int
    var durationSec: Int

    var accuracy: Int {
        total > 0 ? Int(round(Double(score) / Double(total) * 100)) : 0
    }
}

struct ResultsCardView: View {
    let result: QuizResultData
    var topicLabel: String
    var onRetry: () -> Void
    var onNewTopic: () -> Void
    var continueLabel: String = "New Topic"

    var body: some View {
        VStack(spacing: 0) {
            hero
            statsGrid
            actions
        }
        .stickerCard(radius: 24, lift: 6)
        .overlay {
            if grade.letter == "S" || grade.letter == "A" {
                ConfettiView(trigger: 1)
            }
        }
    }

    // MARK: Grade (ResultsCard.tsx gradeFor)

    private var grade: (letter: String, emoji: String, bg: Color, fg: Color, headline: String) {
        switch result.accuracy {
        case 95...: return ("S", "🏆", MLColor.yellow, MLColor.ink, "Outstanding!")
        case 85..<95: return ("A", "🌟", MLColor.mint, MLColor.ink, "Great work!")
        case 70..<85: return ("B", "👍", MLColor.blue, MLColor.ink, "Good effort!")
        case 50..<70: return ("C", "💪", MLColor.purple, .white, "Keep going!")
        case 30..<50: return ("D", "📚", MLColor.coral, .white, "Keep practicing!")
        default: return ("F", "🌱", MLColor.coral, .white, "Try again!")
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            Text(grade.emoji)
                .font(.system(size: 52))
                .scaleEffect(1)
            HStack(spacing: 12) {
                Text(grade.letter)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(grade.fg)
                Text(grade.headline)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(grade.fg)
            }
            Text("\(topicLabel) quiz complete")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(grade.fg.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 18)
        .background(grade.bg)
    }

    private var statsGrid: some View {
        HStack(spacing: 10) {
            StatTile(icon: "target", tone: .white, label: "Score", value: "\(result.score)/\(result.total)")
            StatTile(icon: "trophy.fill", tone: .mint, label: "Accuracy", value: "\(result.accuracy)%")
            StatTile(icon: "bolt.fill", tone: .yellow, label: "XP Earned", value: "+\(result.xpEarned)")
            StatTile(icon: "clock.fill", tone: .blue, label: "Time", value: "\(result.durationSec)s")
        }
        .padding(16)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: onRetry) {
                Label("Retry Quiz", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.stickerCoral)

            Button(action: onNewTopic) {
                Label(continueLabel, systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.stickerWhite)
        }
        .padding(16)
        .padding(.top, 0)
    }
}
