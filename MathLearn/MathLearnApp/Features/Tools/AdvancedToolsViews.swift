//
//  MistakeAnalyzerView.swift + QuizMakerView.swift + PhotoSolverView.swift
//  MathLearn
//
//  Ports of MistakeAnalyzerView.tsx (weakness analysis + repair mixes),
//  QuizMakerView.tsx (custom quiz builder), and PhotoSolverView.tsx
//  (camera → step-by-step solution). Premium-gated features honor the
//  7-day trial via SubscriptionService.effectivePlan.
//

import SwiftUI
import PhotosUI

// MARK: - Mistake Analyzer

struct MistakeAnalyzerView: View {
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var subscription: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var expandedID: String?
    @State private var analyzingID: String?
    @State private var repairMix: [MathQuestion]?
    @State private var repairTopic: MathTopic?

    /// Plus+ feature (web parity: plans.ts mistakeExplainer → plus).
    private var isPlus: Bool { subscription.effectivePlan.rank >= PlanId.plus.rank }

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        StickerBadge(text: "🔍 Mistake Analyzer", tone: MLColor.purple, foreground: .white)
                        Text("Why do I keep missing these?")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(MLColor.ink)
                        Text("Every wrong answer is tracked here with the misconception behind it and a targeted repair mix.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !isPlus {
                        upgradeCard
                    } else if store.mistakes.isEmpty {
                        emptyCard
                    } else {
                        weaknessCard
                        ForEach(store.mistakes.prefix(30)) { mistake in
                            mistakeCard(mistake)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Mistake Analyzer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: Binding(
            get: { repairMix != nil },
            set: { if !$0 { repairMix = nil } }
        )) {
            if let mix = repairMix, let topic = repairTopic {
                NavigationStack {
                    RepairMixDrillView(questions: mix, topic: topic) {
                        repairMix = nil
                    }
                }
            }
        }
    }

    // MARK: Cards

    private var upgradeCard: some View {
        VStack(spacing: 12) {
            Text("⭐")
                .font(.system(size: 40))
            Text("Plus feature")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(MLColor.ink)
            Text("The Mistake Analyzer runs on the Plus tier and above — your 7-day free trial includes it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            NavigationLink {
                PricingView()
            } label: {
                Text("See plans")
                    .frame(maxWidth: 220)
            }
            .buttonStyle(.stickerCoral)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .stickerCard()
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(MLColor.mintStrong)
            Text("No mistakes tracked yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MLColor.ink)
            Text("Wrong answers from practice, quizzes, and games show up here automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(26)
        .stickerCard()
    }

    private var weaknessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            StickerBadge(text: "Weakness finder", tone: MLColor.coral, foreground: .white)
            ForEach(Array(store.weakestTopics.prefix(4).enumerated()), id: \.offset) { _, weak in
                HStack(spacing: 10) {
                    Text(weak.topic.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MLColor.ink)
                        .frame(width: 100, alignment: .leading)
                    StickerProgress(value: weak.mastery, tone: weak.mastery < 40 ? .coral : .yellow)
                    Text("\(Int(weak.mastery.rounded()))%")
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                        .foregroundStyle(MLColor.ink)
                }
            }
            Button {
                startRepairMix()
            } label: {
                Label("Repair mix: 3 questions on \(store.weakestTopics.first?.topic.label ?? "your weakest topic")", systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.stickerYellow)
        }
        .padding(16)
        .stickerCard(radius: 18, lift: 4)
    }

    private func mistakeCard(_ mistake: TrackedMistake) -> some View {
        let expanded = expandedID == mistake.id
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation { expandedID = expanded ? nil : mistake.id }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        StickerBadge(text: mistake.topic.label, tone: MLColor.purple, foreground: .white)
                        StickerBadge(text: mistake.difficulty.rawValue, tone: .white)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    Text(mistake.questionText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MLColor.ink)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        Text("You: \(mistake.userAnswer.isEmpty ? "timed out" : mistake.userAnswer)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(MLColor.coral)
                            .clipShape(Capsule())
                        Text("Correct: \(mistake.correctAnswer)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MLColor.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(MLColor.mint)
                            .clipShape(Capsule())
                    }
                }
            }

            if expanded {
                if let analysis = mistake.analysis {
                    VStack(alignment: .leading, spacing: 8) {
                        analysisRow(icon: "xmark.circle.fill", tint: MLColor.coral, title: "Why it was wrong", body: analysis.whyWrong)
                        analysisRow(icon: "brain.head.profile", tint: MLColor.purple, title: "The misconception", body: analysis.misconception)
                        analysisRow(icon: "lightbulb.fill", tint: MLColor.yellow, title: "How to fix it", body: analysis.fixTip)
                    }
                } else if analyzingID == mistake.id {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Analyzing…")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        analyze(mistake)
                    } label: {
                        Label("Analyze this mistake", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.stickerWhite)
                }
            }
        }
        .padding(14)
        .stickerCard(radius: 16, lift: 3)
    }

    private func analysisRow(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MLColor.ink)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.4))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(MLColor.ink)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MLColor.cream)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Engine

    private func analyze(_ mistake: TrackedMistake) {
        analyzingID = mistake.id
        Task {
            let analysis = await AIService.shared.analyze(mistake: mistake)
            store.setAnalysis(analysis, for: mistake.id)
            analyzingID = nil
        }
    }

    private func startRepairMix() {
        guard let weakest = store.weakestTopics.first else { return }
        repairTopic = weakest.topic
        repairMix = QuestionGenerator.generateQuestions(
            topic: weakest.topic,
            difficulty: weakest.mastery < 35 ? .easy : .medium,
            count: 3
        )
    }
}

// MARK: - Repair mix drill (3-question warm-up)

struct RepairMixDrillView: View {
    @EnvironmentObject private var store: StudyStore
    let questions: [MathQuestion]
    let topic: MathTopic
    let onDone: () -> Void

    @State private var index = 0
    @State private var status: AnswerStatus = .unanswered

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        StickerBadge(text: "🔥 Repair mix", tone: MLColor.coral, foreground: .white)
                        Text("Question \(index + 1) of \(questions.count)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    if questions.indices.contains(index) {
                        QuestionCardView(
                            question: questions[index],
                            index: index,
                            total: questions.count,
                            status: status,
                            onAnswer: answer,
                            onNext: next,
                            nextLabel: index + 1 >= questions.count ? "Finish" : "Next"
                        )
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Warm-Up")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func answer(_ value: String) {
        guard status == .unanswered, questions.indices.contains(index) else { return }
        let q = questions[index]
        let correct = value == q.answer
        status = .answered(selected: value, correct: correct)
        store.recordAnswer(topic: topic, difficulty: q.difficulty, correct: correct)
        if !correct {
            store.trackMistake(question: q, userAnswer: value)
        }
    }

    private func next() {
        if index + 1 >= questions.count {
            onDone()
        } else {
            index += 1
            status = .unanswered
        }
    }
}

// MARK: - Quiz Maker

struct QuizMakerView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @State private var subject: TopicInfo = TopicTree.all[0]
    @State private var subtopic: SubtopicInfo?
    @State private var difficulty: MathDifficulty = .medium
    @State private var count: Double = 6
    @State private var launched: StudySelection?

    var body: some View {
        NavigationStack {
            ZStack {
                MLColor.cream.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            StickerBadge(text: "🪄 Quiz Maker", tone: MLColor.blue, foreground: MLColor.ink)
                            Text("Build a custom quiz")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(MLColor.ink)
                            Text("Pick the subject, topic, difficulty, and length — then run it through the timed quiz engine.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        // Subject
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SUBJECT")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(TopicTree.all) { s in
                                        Button {
                                            subject = s
                                            subtopic = nil
                                        } label: {
                                            Text("\(s.icon) \(s.label)")
                                                .font(.caption.weight(.heavy))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(subject.key == s.key ? MLColor.coral : Color.white)
                                                .foregroundStyle(subject.key == s.key ? .white : MLColor.ink)
                                                .clipShape(Capsule())
                                                .overlay(Capsule().strokeBorder(MLColor.ink, lineWidth: 2))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .stickerCard(radius: 16, lift: 3)

                        // Subtopic
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TOPIC")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            ForEach(subject.subtopics) { sub in
                                Button {
                                    subtopic = sub
                                } label: {
                                    HStack {
                                        Text(sub.label)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(MLColor.ink)
                                        Spacer()
                                        Image(systemName: subtopic?.key == sub.key ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(subtopic?.key == sub.key ? MLColor.mintStrong : .tertiary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(subtopic?.key == sub.key ? MLColor.mint.opacity(0.25) : MLColor.cream)
                                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                }
                            }
                        }
                        .padding(14)
                        .stickerCard(radius: 16, lift: 3)

                        // Difficulty + length
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("DIFFICULTY")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                DifficultyPills(value: $difficulty)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("QUESTIONS")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(0.8)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(count))")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(MLColor.ink)
                                }
                                Slider(value: $count, in: 3...15, step: 1)
                                    .tint(MLColor.coral)
                            }
                        }
                        .padding(14)
                        .stickerCard(radius: 16, lift: 3)

                        Button {
                            build()
                        } label: {
                            Label("Generate & Start", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.stickerCoral)
                        .disabled(subtopic == nil)
                        .opacity(subtopic == nil ? 0.6 : 1)
                    }
                    .padding(16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Quiz Maker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(item: $launched) { selection in
                QuizStageView(selection: selection, questionCount: Int(count), onNewTopic: {
                    launched = nil
                })
            }
        }
    }

    private func build() {
        guard let sub = subtopic else { return }
        launched = StudySelection(
            subjectKey: subject.key,
            subjectLabel: subject.label,
            subtopicKey: sub.key,
            subtopicLabel: sub.label,
            topic: sub.mathTopics.first ?? .arithmetic,
            difficulty: difficulty
        )
    }
}

// MARK: - Photo Solver

struct PhotoSolverView: View {
    @EnvironmentObject private var ai: AIService
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var solution: String?
    @State private var loading = false
    @State private var usedServer = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                MLColor.cream.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            StickerBadge(text: "✨ Photo Solver", tone: MLColor.blue, foreground: MLColor.ink)
                            Text("Snap it. Solve it.")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(MLColor.ink)
                            Text("Take or choose a photo of a math problem and get a step-by-step solution.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 260)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MLColor.ink, lineWidth: 2.5))
                                .frame(maxWidth: .infinity)

                            if loading {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text("Solving…")
                                        .font(.footnote.weight(.heavy))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .stickerCard(radius: 16, lift: 3)
                            } else if let solution {
                                VStack(alignment: .leading, spacing: 8) {
                                    StickerBadge(text: usedServer ? "✨ AI solution" : "📱 Offline guidance", tone: usedServer ? MLColor.mint : MLColor.yellow)
                                    Text(solution)
                                        .font(.footnote)
                                        .foregroundStyle(MLColor.ink)
                                        .lineSpacing(3)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .stickerCard()
                            } else if let error {
                                Text(error)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(MLColor.coral)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            HStack(spacing: 10) {
                                Button {
                                    solve()
                                } label: {
                                    Label("Solve it", systemImage: "wand.and.stars")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.stickerCoral)
                                .disabled(loading)

                                Button {
                                    image = nil
                                    solution = nil
                                    error = nil
                                } label: {
                                    Label("New", systemImage: "arrow.counterclockwise")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.stickerWhite)
                            }
                        } else {
                            PhotosPicker(
                                selection: $pickerItem,
                                matching: .images
                            ) {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 30))
                                        .foregroundStyle(MLColor.coral)
                                    Text("Choose a photo")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(MLColor.ink)
                                    Text("PNG, JPG, HEIC — snap the whole problem")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 220)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color.white)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(MLColor.ink, style: StrokeStyle(lineWidth: 2.5, dash: [8])))
                                .shadow(color: MLColor.ink.opacity(0.85), radius: 0, x: 0, y: 5)
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Photo Solver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        image = ui
                        solution = nil
                        error = nil
                    }
                }
            }
        }
    }

    private func solve() {
        guard let image, !loading else { return }
        loading = true
        error = nil
        Task {
            let data = image.jpegData(compressionQuality: 0.8) ?? Data()
            let (text, server) = await ai.solvePhoto(dataJPEG: data)
            usedServer = server
            solution = text
            loading = false
        }
    }
}
