//
//  QuizSetupView.swift
//  MathLearn
//
//  Port of QuizzesView.tsx — launch a timed 6-question quiz directly
//  from any subject/subtopic, skipping the Learn step.
//

import SwiftUI

struct QuizSetupView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var difficulty: MathDifficulty = .medium
    @State private var subject: TopicInfo?
    @State private var launched: StudySelection?

    private let quizLength = 6

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Quiz")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(MLColor.ink)
                        Text("Jump straight into a timed \(quizLength)-question quiz. Pick a topic and go.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    // Difficulty
                    HStack {
                        Text("Difficulty")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        DifficultyPills(value: $difficulty)
                    }

                    // Quiz info card
                    HStack(spacing: 16) {
                        infoCell(icon: "clock.fill", tone: .blue, title: "Timed", sub: "Per question")
                        infoCell(icon: "flag.fill", tone: .coral, title: "\(quizLength)", sub: "Questions")
                        infoCell(icon: "bolt.fill", tone: .yellow, title: "+XP", sub: "Per correct answer")
                    }
                    .padding(16)
                    .stickerCard(radius: 20, lift: 5)

                    // Breadcrumb
                    HStack(spacing: 6) {
                        Button("Subjects") { withAnimation { subject = nil } }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(subject == nil ? MLColor.ink : .secondary)
                        if let subject {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.tertiary)
                            Text(subject.label)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(MLColor.ink)
                        }
                    }

                    // Subject or subtopic grid
                    if subject == nil {
                        subjectGrid
                    } else {
                        subtopicGrid
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Quizzes")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $launched) { selection in
            QuizStageView(selection: selection, questionCount: quizLength, onNewTopic: {
                launched = nil
                subject = nil
            })
        }
    }

    private var subjectGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            ForEach(TopicTree.all) { s in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { subject = s }
                } label: {
                    HStack(spacing: 14) {
                        Text(s.icon)
                            .font(.system(size: 22))
                            .frame(width: 48, height: 48)
                            .background(Tone(rawValue: s.color)?.bg ?? MLColor.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.label)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(MLColor.ink)
                            Text("\(s.subtopics.count) topics · \(doneCount(s)) done")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .stickerCard(radius: 18, lift: 4)
                }
            }
        }
    }

    private var subtopicGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { subject = nil }
            } label: {
                Label("All subjects", systemImage: "chevron.left")
            }
            .buttonStyle(.stickerWhite)

            LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                ForEach(subject?.subtopics ?? []) { sub in
                    Button {
                        launch(sub)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(sub.label)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(MLColor.ink)
                            StickerProgress(
                                value: store.stats.mastery(for: sub.mathTopics.first ?? .arithmetic),
                                tone: Tone(rawValue: subject?.color ?? "mint") ?? .mint
                            )
                            HStack {
                                Text("\(Int(store.stats.mastery(for: sub.mathTopics.first ?? .arithmetic).rounded()))% mastery")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                HStack(spacing: 2) {
                                    Text("Start quiz")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(MLColor.coral)
                            }
                        }
                        .padding(16)
                        .stickerCard(radius: 18, lift: 4)
                    }
                }
            }
        }
    }

    private func doneCount(_ subject: TopicInfo) -> Int {
        subject.subtopics.filter { store.stats.lessonsCompleted.contains($0.key) }.count
    }

    private func launch(_ sub: SubtopicInfo) {
        guard let parent = subject else { return }
        launched = StudySelection(
            subjectKey: parent.key,
            subjectLabel: parent.label,
            subtopicKey: sub.key,
            subtopicLabel: sub.label,
            topic: sub.mathTopics.first ?? .arithmetic,
            difficulty: difficulty
        )
    }
}

extension StudySelection: Hashable, Identifiable {
    var id: String { "\(subjectKey)|\(subtopicKey)|\(difficulty.rawValue)" }

    static func == (lhs: StudySelection, rhs: StudySelection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
