//
//  AIService.swift
//  MathLearn
//
//  URLSession client for the web app's AI routes (/api/chat,
//  /api/image photo-solve, /api/mistakes/analyze) so both clients
//  share one brain. When the backend is unreachable the service
//  degrades gracefully to a local step-by-step guidance engine so
//  every feature stays usable offline.
//

import Foundation

@MainActor
final class AIService: ObservableObject {

    static let shared = AIService()

    /// Base URL of the MathLearn web backend (editable in Account → AI backend).
    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "mathlearn.apiBase") }
    }

    init() {
        baseURL = UserDefaults.standard.string(forKey: "mathlearn.apiBase") ?? "http://localhost:3000"
    }

    struct ChatMessage: Codable, Equatable, Identifiable {
        var id: UUID = UUID()
        var role: String   // "user" | "assistant"
        var content: String

        enum CodingKeys: String, CodingKey { case role, content }
    }

    private func url(_ path: String) -> URL? {
        URL(string: baseURL.trimmingCharacters(in: .whitespaces) + path)
    }

    // MARK: - Chat tutor (/api/chat)

    /// Sends the conversation; falls back to the local tutor when the
    /// backend is unavailable. Returns (text, usedServer).
    func chat(_ messages: [ChatMessage]) async -> (text: String, usedServer: Bool) {
        struct Body: Codable { var messages: [[String: String]] }
        struct Response: Codable { var success: Bool; var data: Payload?; struct Payload: Codable { var text: String } }

        if let url = url("/api/chat") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            let body = Body(messages: messages.map { ["role": $0.role, "content": $0.content] })
            if let payload = try? JSONEncoder().encode(body) {
                request.httpBody = payload
                if let (data, _) = try? await URLSession.shared.data(for: request),
                   let decoded = try? JSONDecoder().decode(Response.self, from: data),
                   decoded.success, let text = decoded.data?.text, !text.isEmpty {
                    return (text, true)
                }
            }
        }
        return (LocalTutor.respond(to: messages.last?.content ?? ""), false)
    }

    // MARK: - Photo solver (/api/image)

    func solvePhoto(dataJPEG: Data) async -> (text: String, usedServer: Bool) {
        struct Body: Codable { var image: String; var question: String }
        struct Response: Codable { var success: Bool; var data: Payload?; struct Payload: Codable { var text: String } }

        let base64 = dataJPEG.base64EncodedString()
        if let url = url("/api/image") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 45
            let body = Body(image: base64, question: "Solve this math problem step by step.")
            if let payload = try? JSONEncoder().encode(body) {
                request.httpBody = payload
                if let (data, _) = try? await URLSession.shared.data(for: request),
                   let decoded = try? JSONDecoder().decode(Response.self, from: data),
                   decoded.success, let text = decoded.data?.text, !text.isEmpty {
                    return (text, true)
                }
            }
        }
        return (LocalTutor.photoFallback, false)
    }

    // MARK: - Mistake analyzer (/api/mistakes/analyze)

    func analyze(mistake: TrackedMistake) async -> TrackedMistake.MistakeAnalysis {
        struct Body: Codable {
            var isPremium: Bool
            var mistake: Payload
            struct Payload: Codable {
                var id, questionText, correctAnswer, userAnswer: String
                var topic, subject, difficulty: String
                var timestamp: Date
            }
        }
        struct Response: Codable {
            var success: Bool
            var data: Payload?
            struct Payload: Codable {
                var analysis: Analysis?
                struct Analysis: Codable {
                    var whyWrong, misconception, fixTip: String
                }
            }
        }

        if let url = url("/api/mistakes/analyze") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            let body = Body(
                isPremium: true,
                mistake: .init(
                    id: mistake.id,
                    questionText: mistake.questionText,
                    correctAnswer: mistake.correctAnswer,
                    userAnswer: mistake.userAnswer,
                    topic: mistake.topic.rawValue,
                    subject: mistake.subject,
                    difficulty: mistake.difficulty.rawValue,
                    timestamp: mistake.timestamp
                )
            )
            if let payload = try? JSONEncoder().encode(body) {
                request.httpBody = payload
                if let (data, _) = try? await URLSession.shared.data(for: request),
                   let decoded = try? JSONDecoder().decode(Response.self, from: data),
                   decoded.success, let analysis = decoded.data?.analysis {
                    return .init(whyWrong: analysis.whyWrong, misconception: analysis.misconception, fixTip: analysis.fixTip)
                }
            }
        }
        return LocalTutor.analyzeMistake(mistake)
    }
}

// MARK: - Local fallback brain (offline-first)

enum LocalTutor {

    static let photoFallback = """
    Step 1 — Identify what the problem asks.
    Read the given values and the unknown carefully before doing any math.

    Step 2 — Set up the relationship.
    Connect the knowns with the unknown using the relevant rule, keeping units consistent on both sides.

    Step 3 — Solve and check.
    Simplify step by step, then substitute the result back to verify it satisfies the original problem.

    (Offline guidance — connect to the MathLearn backend in Account → AI backend for full AI solving.)
    """

    static func respond(to prompt: String) -> String {
        let p = prompt.lowercased()
        if p.contains("factor") && (p.contains("x²") || p.contains("x2") || p.contains("x^2")) {
            return """
            Factoring a difference of squares works like this:

            1. Recognize the pattern: a² − b² = (a − b)(a + b).
            2. Match your expression to the pattern. For x² − 9: a = x and b = 3, because 9 = 3².
            3. Write the factors: (x − 3)(x + 3).
            4. Check by expanding: x² + 3x − 3x − 9 = x² − 9. ✓

            (Offline tutor — connect to the backend for full AI answers.)
            """
        }
        if p.contains("derivative") || p.contains("chain rule") {
            return """
            The chain rule: d/dx[f(g(x))] = f′(g(x)) · g′(x).

            1. Identify the outer function f and the inner function g.
            2. Differentiate the outer function, leaving the inside untouched.
            3. Multiply by the derivative of the inner function.

            Example: d/dx[(3x + 1)²] = 2(3x + 1) · 3 = 6(3x + 1).

            (Offline tutor — connect to the backend for full AI answers.)
            """
        }
        if p.contains("mean") && p.contains("median") {
            return """
            Mean vs. median:

            • Mean = add every value, then divide by the count. Sensitive to outliers.
            • Median = sort the values and take the middle one (or the average of the two middles). Robust to outliers.

            Example with 2, 3, 100: the mean is 35, but the median is 3 — the outlier drags the mean, not the median.

            (Offline tutor — connect to the backend for full AI answers.)
            """
        }
        if p.contains("solve") || p.contains("equation") {
            return """
            Solving a linear equation, step by step:

            1. Simplify both sides (distribute, combine like terms).
            2. Move variable terms to one side, constants to the other.
            3. Divide both sides by the coefficient of the variable.
            4. Check: substitute your answer back into the original equation.

            Example: 2x + 5 = 17 → 2x = 12 → x = 6. Check: 2(6) + 5 = 17 ✓

            (Offline tutor — connect to the backend for full AI answers.)
            """
        }
        return """
        Here's how I'd approach that:

        1. Restate the problem in your own words and list what's given.
        2. Choose the rule or formula that connects the givens to the goal.
        3. Work one step at a time, writing every line — small steps catch errors early.
        4. Check the result against the original question (units, size, plausibility).

        Try the Practice tab for targeted reps, or connect the AI backend in Account → AI backend for full step-by-step AI answers.
        """
    }

    /// Heuristic offline mistake analysis — groups by topic and answer shape.
    static func analyzeMistake(_ m: TrackedMistake) -> TrackedMistake.MistakeAnalysis {
        let numericUser = Double(m.userAnswer.replacingOccurrences(of: ",", with: "")) != nil
        let signFlipped: Bool = {
            if let user = Double(m.userAnswer), let correct = Double(m.correctAnswer) {
                return user == -correct
            }
            return false
        }()

        let why: String
        let misconception: String
        switch m.topic {
        case .arithmetic, .decimals:
            why = signFlipped
                ? "The magnitude was right but the sign is flipped — the operation order or a negative sign was applied backwards."
                : numericUser
                    ? "The answer is numerically close but off — likely a carrying/borrowing slip or misaligned decimal point."
                    : "The answer doesn't match the computed value — re-run the operation carefully."
            misconception = "Order-of-operations and sign handling need reinforcement."
        case .fractions:
            why = "Fraction work went off track — most often the denominators were added directly or the numerators were cross-multiplied without a common denominator."
            misconception = "Common-denominator reasoning before adding or comparing fractions."
        case .algebra1, .preAlgebra:
            why = "The algebraic isolation went sideways — a constant wasn't moved before dividing, or the coefficient division skipped the constant term."
            misconception = "Inverse operations must be applied in reverse PEMDAS order."
        case .geometry:
            why = "A formula or unit was applied to the wrong quantity — check whether the question asked for area, perimeter, or volume."
            misconception = "Formula selection depends on what the question measures."
        case .calculus, .precalculus:
            why = "The rule application is close but the exponent/constant bookkeeping slipped — recount the power-rule factors."
            misconception = "Power rule multiplies by the old exponent, then decrements it."
        default:
            why = "The selected answer is close to a common trap for this question type — redo the middle step slowly."
            misconception = "Slow down at the transformation step that changes the question's form."
        }
        let fix = "Repair mix: run 3 fresh \(m.topic.label) questions at \(m.difficulty.label.lowercased()) difficulty and re-derive each middle step out loud before answering."
        return TrackedMistake.MistakeAnalysis(whyWrong: why, misconception: misconception, fixTip: fix)
    }
}
