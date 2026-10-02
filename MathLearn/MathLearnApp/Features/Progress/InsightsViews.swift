//
//  InsightsViews.swift
//  MathLearn
//
//  Misconception Detector (Premium) + Likely to Forget (Plus).
//  Ports of src/lib/mistake-analyzer/misconception-detector.ts and
//  src/lib/insights/forgetting.ts.
//
//  Apple APIs used:
//  · SwiftUI — views, sheets, Accessibility (dynamic type friendly text)
//  · Swift Charts — forgetting-percentage bars per topic
//  · NaturalLanguage — NLTokenizer extracts the recurring words from a
//    cluster of mistakes so "topic repeat" cards describe WHAT keeps failing
//  · Foundation — the Ebbinghaus-style exponential decay model
//

import SwiftUI
import Charts
import NaturalLanguage

// MARK: - Misconception Detector (Premium)

/// One recurring misconception found across the user's whole mistake history.
struct MisconceptionPattern: Identifiable {
    let id: String
    let label: String
    let description: String
    let recommendation: String
    var count: Int = 0
    var topics: Set<String> = []
    var examples: [TrackedMistake] = []
    var source: Source = .pattern

    enum Source { case pattern, topicRepeat }

    /// count ÷ total mistakes (0–1).
    func confidence(total: Int) -> Double { total > 0 ? Double(count) / Double(total) : 0 }
    /// A pattern is a misconception once it repeats.
    var isRecurring: Bool { count >= 2 }
}

enum MisconceptionDetector {

    /// Scan EVERY tracked mistake and cluster the recurring error types.
    static func detect(mistakes: [TrackedMistake]) -> [MisconceptionPattern] {
        var byID: [String: MisconceptionPattern] = [:]

        func bump(_ id: String, _ label: String, _ description: String,
                  _ recommendation: String, source: MisconceptionPattern.Source,
                  mistake: TrackedMistake) {
            var pattern = byID[id] ?? MisconceptionPattern(
                id: id, label: label, description: description, recommendation: recommendation, source: source)
            pattern.count += 1
            pattern.topics.insert(mistake.subject)
            if pattern.examples.count < 3 { pattern.examples.append(mistake) }
            byID[id] = pattern
        }

        for m in mistakes {
            guard let u = Self.number(m.userAnswer), let c = Self.number(m.correctAnswer), u != c else { continue }

            // Deterministic answer-shape heuristics — first match wins.
            if u == -c {
                bump("sign_flip", "Sign Flip",
                     "Your answer is the exact opposite sign of the correct one — the classic \"lost the negative\" slip, usually while distributing a negative or moving terms across the equals sign.",
                     "Before submitting, circle every negative sign and re-check the step that produced it.",
                     source: .pattern, mistake: m)
                continue
            }
            if c != 0, abs(u / c - 2) < 0.0001 || (u != 0 && abs(c / u - 2) < 0.0001) {
                bump("double_half", "Doubled / Halved",
                     "Your answer is exactly 2× or ½ of the correct one — a factor-of-two slip (area vs perimeter, diameter vs radius, forgetting to divide by 2).",
                     "Write the formula FIRST — with its factor (½, 2π, ÷2) — then substitute the numbers.",
                     source: .pattern, mistake: m)
                continue
            }
            if abs(u - c) == 1 {
                bump("off_by_one", "Off by One",
                     "Your answer is exactly 1 away from the correct one — a counting-boundary error (inclusive ranges, fences vs posts, rounding too early).",
                     "Test your counting rule on a tiny case (n = 2) before scaling up.",
                     source: .pattern, mistake: m)
                continue
            }
            if Self.sameDigits(u, c) {
                bump("digit_swap", "Transposed Digits",
                     "Right digits, wrong order (24 vs 42) — a transcription slip, not a concept gap.",
                     "Read your final answer back digit-by-digit before submitting.",
                     source: .pattern, mistake: m)
                continue
            }
            if u != 0, c != 0, abs(u / c - 10) < 0.0001 || abs(u / c - 0.1) < 0.0001 {
                bump("place_value", "Place-Value Slip (×10)",
                     "Your answer is 10× or 1/10 of the correct one — decimal-point drift in multiplication and division.",
                     "Estimate the magnitude first (\"about 30 or 300?\") before computing.",
                     source: .pattern, mistake: m)
                continue
            }
            if Self.matchesQuestionNumber(m.questionText, u, excluding: c) {
                bump("stopped_early", "Stopped One Step Early",
                     "Your answer is a number straight from the question — the setup was right but the final operation never happened.",
                     "Re-read what the question asks for (\"total or leftover?\") and box it before you start.",
                     source: .pattern, mistake: m)
                continue
            }
        }

        // Topic repeats — same topic failing repeatedly without one shared shape.
        var topicCounts: [String: [TrackedMistake]] = [:]
        for m in mistakes { topicCounts[m.subject, default: []].append(m) }
        for (topic, group) in topicCounts where group.count >= 2 {
            let keywords = Self.keywords(in: group.map(\.questionText).joined(separator: " "))
            let hint = keywords.isEmpty ? "" : " Common words in your misses: \(keywords.joined(separator: ", "))."
            bump("topic:\(topic)", "Repeat Trouble: \(topic)",
                 "You've missed \(group.count) questions on \(topic) without one shared mechanical pattern — the concept itself needs a re-teach.\(hint)",
                 "Re-watch the \(topic) lesson, then run a 5-question warm-up before your next quiz.",
                 source: .topicRepeat, mistake: group[0])
        }

        // Recurring only, most severe (count × confidence) first.
        let total = mistakes.count
        return byID.values
            .filter { $0.isRecurring }
            .sorted { $0.count * $0.confidence(total: total) > $1.count * $1.confidence(total: total) }
    }

    // MARK: Heuristic helpers

    private static func number(_ raw: String) -> Double? {
        let cleaned = raw.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    private static func sameDigits(_ a: Double, _ b: Double) -> Bool {
        let aDigits = String(abs(Int(a))), bDigits = String(abs(Int(b)))
        return aDigits.count == bDigits.count && aDigits.count >= 2
            && aDigits.sorted() == bDigits.sorted() && aDigits != bDigits
    }

    private static func matchesQuestionNumber(_ question: String, _ answer: Double, excluding correct: Double) -> Bool {
        let mentioned = question.ranges(of: /-?\d+(\.\d+)?/)
            .compactMap { Double(question[$0]) }
        return mentioned.contains { abs($0 - answer) < 0.0001 && abs($0 - correct) > 0.0001 }
    }

    /// NaturalLanguage: pull the recurring meaningful words from a cluster of
    /// missed questions (skips numbers + stopwords) — up to two.
    private static func keywords(in text: String, limit: Int = 2) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var counts: [String: Int] = [:]
        let stopwords: Set<String> = ["what", "is", "the", "a", "of", "to", "how", "many",
                                      "much", "and", "in", "for", "are", "does", "this", "if"]
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range]).lowercased()
            if word.count >= 3, !stopwords.contains(word), Double(word) == nil {
                counts[word, default: 0] += 1
            }
            return true
        }
        return counts.filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map(\.key)
    }
}

struct MisconceptionDetectorView: View {
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var subscription: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var expandedID: String?

    private var isPremium: Bool { subscription.effectivePlan.rank >= PlanId.premium.rank }
    private var patterns: [MisconceptionPattern] { MisconceptionDetector.detect(mistakes: store.mistakes) }

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        StickerBadge(text: "🧠 Misconception Detector", tone: MLColor.coral, foreground: .white)
                        Text("What keeps tripping you up?")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(MLColor.ink)
                        Text("Scans every mistake you make across the whole app and flags the error types that keep coming back.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !isPremium {
                        upgradeCard
                    } else if store.mistakes.isEmpty {
                        emptyCard(title: "Nothing to scan yet",
                                  body: "Practice, quiz, or play — the detector re-scans automatically after every wrong answer.")
                    } else if patterns.isEmpty {
                        emptyCard(title: "No recurring misconceptions",
                                  body: "Your \(store.mistakes.count) mistakes don't share a pattern yet. Keep going — one repeat and you'll see it here.")
                    } else {
                        ForEach(patterns) { pattern in
                            patternCard(pattern, total: store.mistakes.count)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Misconception Detector")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: Cards

    private func patternCard(_ pattern: MisconceptionPattern, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(MLMotion.flip) { expandedID = expandedID == pattern.id ? nil : pattern.id }
            } label: {
                HStack(spacing: 12) {
                    Text("\(pattern.count)×")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .frame(width: 52, height: 44)
                        .background(MLColor.coral, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pattern.label)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(MLColor.ink)
                        Text("\(Int((pattern.confidence(total: total) * 100).rounded()))% of all mistakes · \(pattern.topics.sorted().joined(separator: ", "))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: expandedID == pattern.id ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expandedID == pattern.id {
                VStack(alignment: .leading, spacing: 10) {
                    Text(pattern.description)
                        .font(.footnote)
                        .foregroundStyle(MLColor.ink)
                    ForEach(pattern.examples) { example in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(example.questionText)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MLColor.ink)
                            Text("You: \(example.userAnswer)   ·   Correct: \(example.correctAnswer)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(MLColor.cream.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                    }
                    Label(pattern.recommendation, systemImage: "lightbulb.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MLColor.ink)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MLColor.yellow, in: RoundedRectangle(cornerRadius: 10))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private var upgradeCard: some View {
        VStack(spacing: 12) {
            Text("👑")
                .font(.system(size: 40))
            Text("Premium feature")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(MLColor.ink)
            Text("The Misconception Detector runs on the Premium tier — your 7-day free trial includes it.")
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
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func emptyCard(title: String, body: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundStyle(MLColor.mint)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MLColor.ink)
            Text(body)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Likely to Forget (Plus)

/// One topic's forgetting prediction.
struct ForgetPrediction: Identifiable {
    let topic: String
    /// 0–99 — likelihood the topic has slipped out of memory.
    let forgetPercent: Int
    let daysSince: Double
    let mastery: Int
    let attempts: Int
    var id: String { topic }

    var bandLabel: String {
        switch forgetPercent {
        case 70...: return "Likely forgotten — review now"
        case 50..<70: return "Slipping — practice today"
        case 30..<50: return "Review within days"
        default: return "Still fresh"
        }
    }
    var bandColor: Color {
        switch forgetPercent {
        case 70...: return MLColor.coral
        case 50..<70: return MLColor.yellow
        case 30..<50: return MLColor.blue
        default: return MLColor.mint
        }
    }
}

enum ForgettingModel {
    /// Ebbinghaus-style exponential decay, weighted by mastery, rolling
    /// accuracy, and reps (the memory half-life). Mirrors forgetting.ts.
    static func predict(activity: [String: PlayerStats.TopicActivity],
                        mastery: [String: Double],
                        now: Date = Date()) -> [ForgetPrediction] {
        var out: [ForgetPrediction] = []
        for (raw, entry) in activity {
            let m = mastery[raw] ?? 0
            let accuracy = entry.total > 0 ? Double(entry.correct) / Double(entry.total) : 0.5
            let reps = log2(Double(1 + entry.total))
            let halfLife = 1.5 + (m / 100) * 6 + accuracy * 2 + min(2.5, reps * 0.5)
            let daysSince = max(0, now.timeIntervalSince(entry.lastPracticed) / 86_400)
            let retention = 100 * exp(-daysSince * M_LN2 / halfLife)
            let forget = Int(max(0, min(99, (100 - retention).rounded())))
            out.append(ForgetPrediction(
                topic: raw,
                forgetPercent: forget,
                daysSince: (daysSince * 10).rounded() / 10,
                mastery: Int(m.rounded()),
                attempts: entry.total
            ))
        }
        return out.sorted { $0.forgetPercent > $1.forgetPercent }
    }
}

struct LikelyToForgetView: View {
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var subscription: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    private var isPlus: Bool { subscription.effectivePlan.rank >= PlanId.plus.rank }
    private var predictions: [ForgetPrediction] {
        ForgettingModel.predict(activity: store.stats.topicActivity ?? [:], mastery: store.stats.mastery)
    }

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        StickerBadge(text: "🧠 Likely to Forget", tone: MLColor.purple, foreground: .white)
                        Text("Topics slipping out of memory")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(MLColor.ink)
                        Text("Computed from how long it's been since you practiced each topic, your mastery, accuracy, and reps. Review a topic and watch its percentage drop.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !isPlus {
                        upgradeCard
                    } else if predictions.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 30))
                                .foregroundStyle(MLColor.purple)
                            Text("No data yet")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(MLColor.ink)
                            Text("Answer a few practice questions and your topics appear here with a live forgetting percentage.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(.background, in: RoundedRectangle(cornerRadius: 18))
                    } else {
                        riskChart(predictions)
                        ForEach(predictions) { prediction in
                            predictionRow(prediction)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Likely to Forget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: Swift Charts — forgetting % per topic

    private func riskChart(_ predictions: [ForgetPrediction]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Forgetting risk by topic")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(MLColor.ink)
            Chart(predictions.prefix(8)) { prediction in
                BarMark(
                    x: .value("Forget %", prediction.forgetPercent),
                    y: .value("Topic", prediction.topic)
                )
                .foregroundStyle(prediction.bandColor)
                .cornerRadius(6)
                .annotation(position: .trailing) {
                    Text("\(prediction.forgetPercent)%")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(MLColor.ink)
                }
            }
            .chartXScale(domain: 0...100)
            .frame(height: CGFloat(max(120, min(predictions.count, 8)) * 34))
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func predictionRow(_ prediction: ForgetPrediction) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(prediction.bandColor, lineWidth: 4)
                    .frame(width: 54, height: 54)
                Text("\(prediction.forgetPercent)%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MLColor.ink)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(prediction.topic.replacingOccurrences(of: "-", with: " ").capitalized)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                Text("\(prediction.bandLabel) · last practiced \(Self.daysLabel(prediction.daysSince)) · \(prediction.mastery)% mastery")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var upgradeCard: some View {
        VStack(spacing: 12) {
            Text("⭐")
                .font(.system(size: 40))
            Text("Plus feature")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(MLColor.ink)
            Text("Likely to Forget predicts which topics are slipping — with a percentage — before the test. The Plus tier unlocks it, and your 7-day free trial includes it.")
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
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private static func daysLabel(_ days: Double) -> String {
        switch days {
        case ..<1: return "today"
        case ..<2: return "yesterday"
        default: return "\(Int(days)) days ago"
        }
    }
}
