//
//  MathGamesView.swift
//  MathLearn
//
//  Port of MathGamesView.tsx + the boss-battle game loop: game grid →
//  multi-step instructions → play → ResultsCard. Three Swift-native
//  modes ship here: Boss Battle (HP + combos), Speed Drill (rapid
//  fire), and Equation Match (pair matching) — all driven by the
//  shared question engine, with XP banked through StudyStore.
//

import SwiftUI

struct GameConfig: Identifiable {
    let id: String
    let label: String
    let emoji: String
    let description: String
    let color: Color
    let steps: [String]

    static let all: [GameConfig] = [
        GameConfig(
            id: "boss", label: "Boss Battle", emoji: "🐲",
            description: "Answer questions to attack the boss — wrong answers cost you HP.",
            color: MLColor.coral,
            steps: [
                "The boss starts with 5 HP — every correct answer lands a hit.",
                "Wrong answers drain your own HP — you start with 3 hearts.",
                "Build a combo streak for bonus XP on every third hit.",
                "Defeat the boss before your hearts run out!",
            ]
        ),
        GameConfig(
            id: "speed", label: "Speed Drill", emoji: "⚡",
            description: "60-second rapid-fire round — how many can you solve?",
            color: MLColor.yellow,
            steps: [
                "You get 60 seconds on the clock.",
                "Questions keep coming until time runs out.",
                "Correct answers add time-safe bonus XP; wrong ones cost nothing but time.",
                "Beat your best streak before the buzzer!",
            ]
        ),
        GameConfig(
            id: "match", label: "Equation Match", emoji: "🧩",
            description: "Match each equation to its correct solution — clear the board.",
            color: MLColor.blue,
            steps: [
                "Six tiles appear: three equations, three solutions.",
                "Tap an equation, then tap the solution that pairs with it.",
                "A correct pair locks in and disappears — a miss costs a few seconds.",
                "Clear the whole board as fast as you can!",
            ]
        ),
    ]
}

struct MathGamesView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeGame: GameConfig?
    @State private var showInstructions = true
    @State private var result: QuizResultData?

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    if let result {
                        ResultsCardView(
                            result: result,
                            topicLabel: activeGame?.label ?? "Game",
                            onRetry: { showGrid() },
                            onNewTopic: { showGrid() },
                            continueLabel: "Back to Games"
                        )
                        .transition(MLMotion.phaseTransition(reduceMotion: reduceMotion))
                    } else if let game = activeGame {
                        if showInstructions {
                            instructions(game)
                                .transition(MLMotion.phaseTransition(reduceMotion: reduceMotion))
                        } else {
                            play(game)
                                .transition(MLMotion.phaseTransition(reduceMotion: reduceMotion))
                        }
                    } else {
                        grid
                            .transition(MLMotion.phaseTransition(reduceMotion: reduceMotion))
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Math Games")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Phase swaps (M3 — animation context outside the conditionals)

    private func showGrid() {
        withAnimation(reduceMotion ? MLMotion.crossfade : MLMotion.selection) {
            result = nil
            activeGame = nil
            showInstructions = true
        }
    }

    private func begin(_ game: GameConfig) {
        withAnimation(reduceMotion ? MLMotion.crossfade : MLMotion.selection) {
            activeGame = game
            showInstructions = true
        }
    }

    private func exitToGrid() {
        withAnimation(reduceMotion ? MLMotion.crossfade : MLMotion.selection) {
            activeGame = nil
        }
    }

    private func startPlaying() {
        withAnimation(reduceMotion ? MLMotion.crossfade : MLMotion.selection) {
            showInstructions = false
        }
    }

    // MARK: Grid

    private var grid: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                badgeText: "🎮 Games",
                badgeTone: .purple,
                title: "Math Games",
                subtitle: "Battle math bosses across game modes. Each game starts with instructions — learn the controls, then play!"
            )
            HStack(spacing: 12) {
                infoCell(icon: "gamecontroller.fill", title: "3", sub: "game modes")
                infoCell(icon: "bolt.fill", title: "XP", sub: "per win")
                infoCell(icon: "trophy.fill", title: "Bests", sub: "tracked")
            }
            .padding(14)
            .stickerCard(radius: 18, lift: 4)

            ForEach(GameConfig.all) { game in
                Button {
                    begin(game)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            Text(game.emoji)
                                .font(.system(size: 26))
                                .frame(width: 54, height: 54)
                                .background(game.color.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            Spacer()
                            StickerBadge(text: "Play", tone: MLColor.coral, foreground: .white)
                        }
                        Text(game.label)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(MLColor.ink)
                        Text(game.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 5) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 10))
                            Text("Touch controls")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(MLColor.cream)
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(16)
                    .stickerCard(radius: 18, lift: 4)
                }
            }
        }
    }

    private func infoCell(icon: String, title: String, sub: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(MLColor.coral)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                Text(sub)
                    .font(.system(size: 9, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Instructions (GameInstructions.tsx multi-step flow)

    @State private var instructionStep = 0

    private func instructions(_ game: GameConfig) -> some View {
        let last = instructionStep >= game.steps.count - 1
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    exitToGrid()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("INSTRUCTIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text("How to Play")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(MLColor.ink)
                }
            }

            VStack(spacing: 14) {
                Text(game.emoji)
                    .font(.system(size: 44))
                    .frame(width: 84, height: 84)
                    .background(game.color.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .stickerCard(radius: 22, lift: 5)
                Text(game.label)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                Text(game.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    ForEach(0..<game.steps.count, id: \.self) { i in
                        Capsule()
                            .fill(i == instructionStep ? MLColor.coral : MLColor.ink.opacity(0.15))
                            .frame(width: i == instructionStep ? 22 : 10, height: 6)
                    }
                }

                Text(game.steps[instructionStep])
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MLColor.ink)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 70)

                Button {
                    if last {
                        startPlaying()
                    } else {
                        withAnimation(reduceMotion ? MLMotion.crossfade : MLMotion.selection) {
                            instructionStep += 1
                        }
                    }
                } label: {
                    Text(last ? "Let's Play!" : "Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.stickerCoral)
            }
            .padding(20)
            .stickerCard()
        }
        .onAppear { instructionStep = 0 }
    }

    // MARK: Play

    @State private var playSeed = UUID()

    private func play(_ game: GameConfig) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(reduceMotion ? MLMotion.crossfade : MLMotion.selection) {
                        activeGame = nil
                        showInstructions = true
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(game.emoji) \(game.label)")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    Text("Now playing")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(MLColor.ink)
                }
            }
            .id(playSeed)

            switch game.id {
            case "speed": SpeedDrillGame(difficulty: .medium, onFinish: { result = $0; bank($0) })
            case "match": EquationMatchGame(difficulty: .easy, onFinish: { result = $0; bank($0) })
            default: BossBattleGame(difficulty: .medium, onFinish: { result = $0; bank($0) })
            }
        }
    }

    private func bank(_ result: QuizResultData) {
        store.awardXP(result.xpEarned)
        if result.score >= 1 {
            store.setLastStudied(
                courseSlug: activeGame?.id ?? "games",
                courseLabel: activeGame?.label ?? "Math Games",
                lessonTitle: activeGame?.label ?? "Math Games",
                topic: .arithmetic,
                stage: "results"
            )
        }
    }
}
