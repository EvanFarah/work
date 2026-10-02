//
//  PPTMakerView.swift
//  MathLearn
//
//  FREE-tier PPT Maker: turns any topic into a shareable study deck.
//  Slides are built from the local curriculum engine — the question
//  generator's hints become the method slides, its worked questions
//  become example + your-turn pairs — so a deck always teaches the
//  same way the practice drills do. Quota = plan.pptDecks per month
//  (Free 5 · Plus 50 · Premium 100), counted by FeatureUsage.
//
//  Apple APIs used:
//  · SwiftUI — TabView(.page) deck pager, ShareLink (deck outline export)
//  · Foundation — UserDefaults month-keyed quota counter (FeatureUsage)
//

import SwiftUI

// MARK: - Deck model

struct PPTSlide: Identifiable {
    let id: Int
    let title: String
    let bullets: [String]
    let kind: Kind

    enum Kind { case title, idea, method, example, practice, answer, recap }
}

// MARK: - Deck builder (local curriculum engine, offline-first)

enum PPTMaker {

    static func build(subject: TopicInfo, subtopic: SubtopicInfo,
                      difficulty: MathDifficulty, examples: Int) -> [PPTSlide] {
        let topic = subtopic.mathTopics.first ?? .arithmetic
        let questions = QuestionGenerator.generateQuestions(
            topic: topic, difficulty: difficulty, count: max(2, examples * 2))
        var slides: [PPTSlide] = []
        var nextID = 0

        func push(_ title: String, _ bullets: [String], _ kind: PPTSlide.Kind) {
            slides.append(PPTSlide(id: nextID, title: title, bullets: bullets, kind: kind))
            nextID += 1
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let stamp = formatter.string(from: Date())

        // 1 · Title slide
        push(subtopic.label, ["\(subject.label) · \(difficulty.label)", "MathLearn study deck · \(stamp)"], .title)

        // 2 · The big idea
        push("The Big Idea", [
            "What \(subtopic.label.lowercased()) is and why it shows up everywhere in \(subject.label.lowercased()).",
            "Goal: solve \(difficulty.label.lowercased()) problems on your own by the last slide.",
        ], .idea)

        // 3 · The method — every hint in the set, deduped, numbered
        var seenHints: Set<String> = []
        let methods = questions.compactMap(\.hint).filter { seenHints.insert($0).inserted }
        if !methods.isEmpty {
            push("The Method", methods.prefix(4).enumerated().map { "\($0.offset + 1). \($0.element)" }, .method)
        }

        // 4 · Example / your-turn pairs
        for (i, q) in questions.prefix(examples).enumerated() {
            push("Worked Example \(i + 1)", [
                q.question,
                "Method: \(q.hint)",
                "Answer: \(q.answer) — \(q.explanation)",
            ], .example)
        }
        for (i, q) in questions.prefix(examples).enumerated() {
            push("Your Turn \(i + 1)", [q.question] + q.options.map { "·  \($0)" }, .practice)
        }
        for (i, q) in questions.prefix(examples).enumerated() {
            push("Your Turn \(i + 1) — Answer", [
                "Correct: \(q.answer)",
                q.explanation,
                "Method: \(q.hint)",
            ], .answer)
        }

        // 5 · Recap
        push("Key Takeaways", (methods.prefix(3) + ["Re-run these as practice drills to lock the method in."])
            .map { "•  \($0)" }, .recap)

        return slides
    }

    /// Plain-text outline for ShareLink export.
    static func outline(for deck: [PPTSlide], subject: TopicInfo, subtopic: SubtopicInfo) -> String {
        var lines = ["MathLearn Study Deck — \(subtopic.label)", "\(subject.label)", ""]
        for (i, slide) in deck.enumerated() {
            lines.append("SLIDE \(i + 1) — \(slide.title)")
            lines.append(contentsOf: slide.bullets.map { "  \($0)" })
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - View

struct PPTMakerView: View {
    @EnvironmentObject private var subscription: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var subject: TopicInfo = TopicTree.all[0]
    @State private var subtopic: SubtopicInfo?
    @State private var difficulty: MathDifficulty = .medium
    @State private var examples: Double = 2
    @State private var deck: [PPTSlide]?
    @State private var slideIndex = 0

    private let usage = FeatureUsage(feature: "ppt-decks")
    private var quota: Int { Plan.by(id: subscription.effectivePlan).pptDecks }
    private var remaining: Int? { usage.remaining(quota: quota) }

    var body: some View {
        NavigationStack {
            ZStack {
                MLColor.cream.ignoresSafeArea()
                if let deck {
                    deckPager(deck)
                } else {
                    setupForm
                }
            }
            .navigationTitle("PPT Maker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(deck == nil ? "Close" : "Back") {
                        if deck != nil { deck = nil; slideIndex = 0 } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let deck, let deckSubtopic = subtopic {
                        ShareLink(item: PPTMaker.outline(for: deck, subject: subject, subtopic: deckSubtopic)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.callout.weight(.bold))
                        }
                    }
                }
            }
        }
    }

    // MARK: Setup form

    private var setupForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    StickerBadge(text: "🗂 PPT Maker", tone: MLColor.blue, foreground: MLColor.ink)
                    Text("Build a study deck")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(MLColor.ink)
                    Text("Any topic becomes slides: the big idea, the method, worked examples, and your-turn practice. Free on every plan.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                quotaChip
                    .padding(.vertical, 2)

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

                // Difficulty + example count
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
                            Text("WORKED EXAMPLES")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(examples))")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(MLColor.ink)
                        }
                        Slider(value: $examples, in: 1...4, step: 1)
                            .tint(MLColor.coral)
                    }
                }
                .padding(14)
                .stickerCard(radius: 16, lift: 3)

                Button {
                    generate()
                } label: {
                    Label("Generate Deck", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.stickerCoral)
                .disabled(subtopic == nil || (remaining ?? 0) == 0)
                .opacity(subtopic == nil || (remaining ?? 0) == 0 ? 0.6 : 1)
            }
            .padding(16)
            .padding(.bottom, 28)
        }
    }

    private var quotaChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MLColor.mintStrong)
            if let remaining {
                Text("\(remaining) of \(quota) decks left this month")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MLColor.ink)
            } else {
                Text("Unlimited decks this month")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MLColor.ink)
            }
            Spacer()
        }
        .padding(10)
        .background(MLColor.mint.opacity(0.14))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(MLColor.mintStrong.opacity(0.3), lineWidth: 1))
    }

    // MARK: Deck pager

    private func deckPager(_ deck: [PPTSlide]) -> some View {
        VStack(spacing: 14) {
            TabView(selection: $slideIndex) {
                ForEach(deck) { slide in
                    slideCard(slide)
                        .tag(slide.id)
                        .padding(.horizontal, 20)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack {
                Button {
                    withAnimation { slideIndex = max(0, slideIndex - 1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
                }
                .disabled(slideIndex == 0)
                .opacity(slideIndex == 0 ? 0.4 : 1)

                Spacer()
                Text("Slide \(slideIndex + 1) of \(deck.count)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Spacer()

                Button {
                    withAnimation { slideIndex = min(deck.count - 1, slideIndex + 1) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
                }
                .disabled(slideIndex >= deck.count - 1)
                .opacity(slideIndex >= deck.count - 1 ? 0.4 : 1)
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func slideCard(_ slide: PPTSlide) -> some View {
        switch slide.kind {
        case .title:
            VStack(spacing: 10) {
                StickerBadge(text: slide.bullets.last ?? "Study deck", tone: MLColor.coral, foreground: .white)
                Text(slide.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                    .multilineTextAlignment(.center)
                Text(slide.bullets.first ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MLColor.mint.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(MLColor.mintStrong.opacity(0.4), lineWidth: 2))
            .padding(.vertical, 14)
        default:
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StickerBadge(
                        text: badge(for: slide.kind),
                        tone: tone(for: slide.kind),
                        foreground: tone(for: slide.kind) == MLColor.yellow || tone(for: slide.kind) == MLColor.mint ? MLColor.ink : .white
                    )
                    Spacer()
                }
                Text(slide.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(slide.bullets, id: \.self) { bullet in
                        Text(bullet)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(MLColor.ink)
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(bulletBackground(for: slide.kind))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .stickerCard(radius: 24, lift: 5)
            .padding(.vertical, 14)
        }
    }

    private func badge(for kind: PPTSlide.Kind) -> String {
        switch kind {
        case .idea: return "💡 The Big Idea"
        case .method: return "🧭 The Method"
        case .example: return "✏️ Worked Example"
        case .practice: return "🎯 Your Turn"
        case .answer: return "✅ Answer"
        case .recap: return "🏁 Key Takeaways"
        case .title: return "Study Deck"
        }
    }

    private func tone(for kind: PPTSlide.Kind) -> Color {
        switch kind {
        case .idea: return MLColor.blue
        case .method: return MLColor.mint
        case .example: return MLColor.purple
        case .practice: return MLColor.coral
        case .answer: return MLColor.mint
        case .recap: return MLColor.yellow
        case .title: return MLColor.coral
        }
    }

    private func bulletBackground(for kind: PPTSlide.Kind) -> Color {
        kind == .answer ? MLColor.mint.opacity(0.16) : MLColor.cream
    }

    // MARK: Engine

    private func generate() {
        guard let sub = subtopic else { return }
        deck = PPTMaker.build(subject: subject, subtopic: sub, difficulty: difficulty, examples: Int(examples))
        usage.increment()
    }
}
