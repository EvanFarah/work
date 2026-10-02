//
//  LiveWorkCheckView.swift
//  MathLearn
//
//  PREMIUM-only Live Work Check: you solve a problem line by line, and
//  EVERY line is validated the moment you submit it — not just the final
//  answer. The engine evaluates each line arithmetically and, when a line
//  is off, classifies HOW it is off (sign flip, off-by-one, ×10 place
//  value, transposed digits, sides that disagree) and teaches the fix
//  right there. Same heuristic family as the Misconception Detector.
//
//  Quota: plan.liveChecks per month (Premium 2,500) via FeatureUsage.
//
//  Apple APIs used:
//  · SwiftUI — views, FocusState (keyboard flow), Accessibility labels
//  · Foundation — UserDefaults month-keyed quota counter (FeatureUsage)
//  · Foundation — pow/abs arithmetic for the recursive-descent parser
//

import SwiftUI

// MARK: - Work-check engine (offline)

enum WorkCheckEngine {

    enum Verdict: Equatable {
        case ok(Double)
        case signFlip(expected: Double)
        case offByOne(expected: Double)
        case placeValue(expected: Double)
        case transposed(expected: Double)
        case sidesDisagree(left: Double, right: Double)
        case mismatch(expected: Double)
        case notMath
    }

    /// Evaluates one line of working: numbers, + − × ÷ ^ ( ), decimals.
    /// Lines may be bare expressions ("48 − 18 = 30") or equations —
    /// both sides are checked against each other.
    static func evaluate(_ raw: String) -> Double? {
        let parts = raw.components(separatedBy: "=")
        switch parts.count {
        case 1:
            return Parser(parts[0]).parse()
        case 2:
            let left = parts[0].trimmingCharacters(in: .whitespaces)
            let right = parts[1].trimmingCharacters(in: .whitespaces)
            if left.isEmpty { return Parser(right).parse() }
            if right.isEmpty { return Parser(left).parse() }
            return Parser(right).parse() // value of the line = its result side
        default:
            return nil
        }
    }

    /// Checks one submitted line against the running expected value.
    static func check(_ raw: String, expected: Double?) -> Verdict {
        let parts = raw.components(separatedBy: "=")
        if parts.count == 2 {
            let leftRaw = parts[0].trimmingCharacters(in: .whitespaces)
            let rightRaw = parts[1].trimmingCharacters(in: .whitespaces)
            if !leftRaw.isEmpty, !rightRaw.isEmpty {
                // Both sides must be verifiable arithmetic — a line like
                // "3x + 5 = 20" can't be checked, so ask for numbers
                // instead of silently accepting the right side.
                guard let left = Parser(leftRaw).parse(), let right = Parser(rightRaw).parse() else {
                    return .notMath
                }
                if abs(left - right) >= 0.0001 { return .sidesDisagree(left: left, right: right) }
                return expected.map { classify(right, expected: $0) } ?? .ok(right)
            }
        }
        guard let value = evaluate(raw) else { return .notMath }
        guard let expected else { return .ok(value) } // first line seeds the chain
        return classify(value, expected: expected)
    }

    /// Answer-shape heuristics — first match wins (Misconception family).
    static func classify(_ value: Double, expected: Double) -> Verdict {
        if abs(value - expected) < 0.0001 { return .ok(value) }
        if expected != 0, abs(value + expected) < 0.0001 { return .signFlip(expected: expected) }
        if abs(abs(value - expected) - 1) < 0.0001 { return .offByOne(expected: expected) }
        if expected != 0, abs(value / expected - 10) < 0.0001 || abs(value / expected - 0.1) < 0.0001 {
            return .placeValue(expected: expected)
        }
        if sameDigits(value, expected) { return .transposed(expected: expected) }
        return .mismatch(expected: expected)
    }

    private static func sameDigits(_ a: Double, _ b: Double) -> Bool {
        let aDigits = String(abs(Int(a))), bDigits = String(abs(Int(b)))
        return aDigits.count == bDigits.count && aDigits.count >= 2
            && aDigits.sorted() == bDigits.sorted() && aDigits != bDigits
    }

    /// Recursive-descent arithmetic parser (numbers, + - * / ^, unary minus,
    /// parentheses). "×"/"·"/"x" mean multiply ONLY when x sits between two
    /// values ("6 x 7") — "3x + 5" keeps its letter and fails cleanly to
    /// .notMath instead of mis-parsing implicit multiplication. Unicode
    /// dashes normalize to "-".
    private struct Parser {
        private var chars: [Character]
        private var i = 0

        init(_ raw: String) {
            let source = Array(raw.lowercased())
            let swaps: [Character: Character] = ["×": "*", "÷": "/", "−": "-", "–": "-", "—": "-", "·": "*"]
            var out: [Character] = []
            for (idx, ch) in source.enumerated() {
                if ch == " " || ch == "," { continue }
                if ch == "x" {
                    // Multiply only when sandwiched: digit/')' before, digit/'(' after.
                    let prevIsValue = out.last.map { $0.isNumber || $0 == ")" } ?? false
                    var j = idx + 1
                    while j < source.count, source[j] == " " { j += 1 }
                    let nextIsValue = j < source.count && (source[j].isNumber || source[j] == "(")
                    out.append(prevIsValue && nextIsValue ? "*" : ch) // bare 'x' fails parse → notMath
                    continue
                }
                out.append(swaps[ch] ?? ch)
            }
            chars = out
        }

        /// Parses the whole input as one expression; nil if malformed or
        /// trailing garbage remains.
        mutating func parse() -> Double? {
            guard let value = expression(), i >= chars.count else { return nil }
            return value.isFinite ? value : nil
        }

        private mutating func expression() -> Double? {
            guard var value = term() else { return nil }
            while i < chars.count, chars[i] == "+" || chars[i] == "-" {
                let op = chars[i]; i += 1
                guard let rhs = term() else { return nil }
                value = op == "+" ? value + rhs : value - rhs
            }
            return value
        }

        private mutating func term() -> Double? {
            guard var value = power() else { return nil }
            while i < chars.count, chars[i] == "*" || chars[i] == "/" {
                let op = chars[i]; i += 1
                guard let rhs = power() else { return nil }
                if op == "*" { value *= rhs } else {
                    guard rhs != 0 else { return nil }
                    value /= rhs
                }
            }
            return value
        }

        private mutating func power() -> Double? {
            guard let base = unary() else { return nil }
            if i < chars.count, chars[i] == "^" {
                i += 1
                guard let exponent = power() else { return nil }
                return pow(base, exponent)
            }
            return base
        }

        private mutating func unary() -> Double? {
            if i < chars.count, chars[i] == "-" { i += 1; return unary().map { -$0 } }
            if i < chars.count, chars[i] == "+" { i += 1; return unary() }
            return primary()
        }

        private mutating func primary() -> Double? {
            if i < chars.count, chars[i] == "(" {
                i += 1
                guard let value = expression(), i < chars.count, chars[i] == ")" else { return nil }
                i += 1
                return value
            }
            let start = i
            while i < chars.count, chars[i].isNumber || chars[i] == "." { i += 1 }
            guard i > start, let value = Double(String(chars[start..<i])) else { return nil }
            return value
        }
    }
}

// MARK: - View

struct LiveWorkCheckView: View {
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var subscription: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    private var isPremium: Bool { subscription.effectivePlan.rank >= PlanId.premium.rank }

    private enum Mode { case setup, working, done }
    @State private var mode: Mode = .setup
    @State private var subject: TopicInfo = TopicTree.all[0]
    @State private var subtopic: SubtopicInfo?
    @State private var difficulty: MathDifficulty = .easy

    @State private var problem: MathQuestion?
    @State private var expected: Double?
    @State private var answerValue: Double?
    @State private var steps: [CheckedStep] = []
    @State private var stepInput = ""
    @FocusState private var stepFieldFocused: Bool

    struct CheckedStep: Identifiable {
        let id = UUID()
        let text: String
        let verdict: WorkCheckEngine.Verdict
        var isOK: Bool { if case .ok = verdict { return true }; return false }
    }

    private let usage = FeatureUsage(feature: "live-checks")
    private var quota: Int { Plan.by(id: subscription.effectivePlan).liveChecks }
    private var remaining: Int? { usage.remaining(quota: quota) }

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            if !isPremium {
                upgradeCard
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        switch mode {
                        case .setup: setupForm
                        case .working: workSheet
                        case .done: summaryCard
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 28)
                }
            }
        }
        .navigationTitle("Live Work Check")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: Gate

    private var upgradeCard: some View {
        VStack(spacing: 12) {
            Text("👑")
                .font(.system(size: 40))
            Text("Premium feature")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(MLColor.ink)
            Text("Live Work Check validates your working line by line as you solve — catching sign, calculation, and place-value slips the second you write them. Your 7-day free trial includes it.")
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
        .padding(.top, 40)
    }

    // MARK: Setup

    private var setupForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                StickerBadge(text: "✅ Live Work Check", tone: MLColor.mint, foreground: MLColor.ink)
                Text("Show your work — I'll watch every line")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                Text("Solve step by step; each line is checked the moment you submit it, and a slip is diagnosed and fixed on the spot.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            quotaChip

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

            HStack {
                Text("DIFFICULTY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                DifficultyPills(value: $difficulty)
            }
            .padding(14)
            .stickerCard(radius: 16, lift: 3)

            Button {
                start()
            } label: {
                Label("Start Checking", systemImage: "checkmark.seal.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.stickerCoral)
            .disabled(subtopic == nil || (remaining ?? 0) == 0)
            .opacity(subtopic == nil || (remaining ?? 0) == 0 ? 0.6 : 1)
        }
    }

    private var quotaChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MLColor.mintStrong)
            if let remaining {
                Text("\(remaining) checks left this month")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MLColor.ink)
            } else {
                Text("Unlimited checks this month")
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

    // MARK: Work sheet

    private var workSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let problem {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        StickerBadge(text: problem.topic.label, tone: MLColor.blue, foreground: MLColor.ink)
                        StickerBadge(text: problem.difficulty.rawValue, tone: .white)
                        Spacer()
                        Button {
                            mode = .setup
                            problem = nil
                            steps = []
                        } label: {
                            Label("New", systemImage: "arrow.counterclockwise")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(problem.question)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(MLColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Type one line of working at a time — e.g. \"48 − 18 = 30\". The method: \(problem.hint)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
                .padding(16)
                .stickerCard()

                // Checked lines
                VStack(alignment: .leading, spacing: 8) {
                    if steps.isEmpty {
                        Text("Your working appears here, checked line by line.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    }
                    ForEach(steps) { step in
                        stepRow(step)
                    }
                }
                .padding(14)
                .stickerCard(radius: 18, lift: 4)

                // Input bar (in-flow, solid — never glass per §3)
                HStack(spacing: 10) {
                    TextField("Next line of working…", text: $stepInput)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.send)
                        .focused($stepFieldFocused)
                        .onSubmit(submitStep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MLColor.ink.opacity(0.2), lineWidth: 1.5))

                    Button(action: submitStep) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(MLColor.coral)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(stepInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(stepInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    .accessibilityLabel("Check this line")
                }

                if solved {
                    Button {
                        finish()
                    } label: {
                        Label(steps.allSatisfy(\.isOK) ? "Solved Clean — Bank XP" : "Solved — Finish & Review",
                              systemImage: "flag.checkered")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.stickerYellow)
                }
            }
        }
    }

    private func stepRow(_ step: CheckedStep) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: step.isOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(step.isOK ? MLColor.mintStrong : MLColor.coral)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.text)
                    .font(.footnote.weight(.semibold).monospaced())
                    .foregroundStyle(MLColor.ink)
                Text(verdictMessage(step.verdict))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(step.isOK ? MLColor.mintStrong : MLColor.coral)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(step.isOK ? MLColor.mint.opacity(0.14) : MLColor.coral.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var solved: Bool {
        guard let answerValue, let last = steps.last else { return false }
        guard case .ok(let value) = last.verdict else { return false }
        return abs(value - answerValue) < 0.0001
    }

    private func verdictMessage(_ verdict: WorkCheckEngine.Verdict) -> String {
        switch verdict {
        case .ok:
            return "Checks out — this line is arithmetically sound."
        case .signFlip:
            return "Sign flip: this is the exact opposite of the previous value. Circle every negative sign and re-check the step that produced it."
        case .offByOne:
            return "Off by one: counting-boundary slip. Test your counting rule on a tiny case before scaling up."
        case .placeValue:
            return "Place-value slip (×10): the decimal point drifted. Estimate the magnitude first — “about 30 or 300?”"
        case .transposed:
            return "Transposed digits: right digits, wrong order. Read the final answer back digit-by-digit."
        case .sidesDisagree(let left, let right):
            return "The two sides of this line disagree: \(fmt(left)) ≠ \(fmt(right)). Re-run the left side before moving on."
        case .mismatch(let expected):
            return "Doesn't follow from the previous line (expected \(fmt(expected))). Re-derive this step slowly."
        case .notMath:
            return "I can only check numbers for now — rewrite the line with the numbers you have, e.g. \"48 − 18 = 30\"."
        }
    }

    private func fmt(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.2f", value)
    }

    // MARK: Summary

    private var summaryCard: some View {
        VStack(spacing: 12) {
            Image(systemName: steps.allSatisfy(\.isOK) ? "checkmark.seal.fill" : "wrench.and.screwdriver.fill")
                .font(.system(size: 30))
                .foregroundStyle(steps.allSatisfy(\.isOK) ? MLColor.mintStrong : MLColor.yellow)
            Text(steps.allSatisfy(\.isOK) ? "Clean solve!" : "Solved with \(steps.filter { !$0.isOK }.count) caught slip\(steps.filter { !$0.isOK }.count == 1 ? "" : "s")")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(MLColor.ink)
            Text("Every line you write gets checked in the moment — that's how silly mistakes stop reaching the page.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: step.isOK ? "checkmark" : "xmark")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(step.isOK ? MLColor.mintStrong : MLColor.coral)
                        .padding(.top, 2)
                    Text(step.text)
                        .font(.caption.weight(.semibold).monospaced())
                        .foregroundStyle(MLColor.ink)
                    Spacer()
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MLColor.cream)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            Button {
                mode = .setup
                problem = nil
                steps = []
            } label: {
                Label("Check Another Problem", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.stickerWhite)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .stickerCard()
        .padding(.top, 20)
    }

    // MARK: Engine

    private func start() {
        guard let sub = subtopic else { return }
        let topic = sub.mathTopics.first ?? .arithmetic
        let question = QuestionGenerator.generateQuestion(topic: topic, difficulty: difficulty, subtopic: sub.key)
        problem = question
        answerValue = WorkCheckEngine.evaluate(question.answer) ?? Double(question.answer)
        // Seed the chain from the problem's own left side when it is numeric
        // ("48 ÷ 6 = ?" → 8). Worded / variable stems fail to parse → nil,
        // and the first submitted line then seeds the chain instead.
        let stem = (question.question.components(separatedBy: "=").first ?? question.question)
            .replacingOccurrences(of: "?", with: "")
        expected = WorkCheckEngine.evaluate(stem)
        steps = []
        stepInput = ""
        usage.increment()
        store.setLastStudied(
            courseSlug: subject.key, courseLabel: subject.label,
            lessonTitle: sub.label, topic: topic, stage: "practice"
        )
    }

    private func submitStep() {
        let raw = stepInput.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        let verdict = WorkCheckEngine.check(raw, expected: expected)
        steps.append(CheckedStep(text: raw, verdict: verdict))
        if case .ok(let value) = verdict {
            expected = value // chain continues from the last sound line
        }
        stepInput = ""
        stepFieldFocused = true
    }

    private func finish() {
        if let problem {
            store.recordAnswer(topic: problem.topic, difficulty: problem.difficulty, correct: steps.allSatisfy(\.isOK))
            if !steps.allSatisfy(\.isOK) {
                store.trackMistake(question: problem, userAnswer: "working had \(steps.filter { !$0.isOK }.count) flagged line(s)")
            }
        }
        withAnimation(MLMotion.selection) { mode = .done }
    }
}
