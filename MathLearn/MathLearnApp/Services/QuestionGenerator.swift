//
//  QuestionGenerator.swift
//  MathLearn
//
//  Swift port of src/lib/math/questions.ts — the procedural question
//  engine. 13 topic generators with difficulty ranges, distractor
//  construction (makeOptions), and the answer-presence safety net.
//  The lesson-template "boss" variation system on the web layers on
//  top of these same generators; the iOS app uses the generators
//  directly for all practice, quizzes, games, and quiz maker.
//

import Foundation

enum QuestionGenerator {

    // MARK: - Public API (questions.ts generateQuestions)

    static func generateQuestions(
        topic: MathTopic,
        difficulty: MathDifficulty = .medium,
        count: Int = 5,
        subtopic: String? = nil
    ) -> [MathQuestion] {
        (0..<count).map { _ in generateQuestion(topic: topic, difficulty: difficulty, subtopic: subtopic) }
    }

    static func generateQuestion(
        topic: MathTopic,
        difficulty: MathDifficulty,
        subtopic: String? = nil
    ) -> MathQuestion {
        ensureAnswerPresent(generate(topic, difficulty, subtopic))
    }

    // MARK: - Shared helpers (questions.ts)

    private static func rand(_ min: Int, _ max: Int) -> Int {
        Int.random(in: min...max)
    }

    private static func pick<T>(_ arr: [T]) -> T {
        arr.randomElement()!
    }

    private static func shuffle<T>(_ arr: [T]) -> [T] {
        arr.shuffled()
    }

    private static func gcd(_ a0: Int, _ b0: Int) -> Int {
        var a = abs(a0), b = abs(b0)
        while b != 0 { (a, b) = (b, a % b) }
        return a
    }

    private static func fmt(_ n: Double) -> String {
        if n == n.rounded() && abs(n) < 1e12 { return String(Int(n)) }
        var s = String(format: "%.2f", n)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    private static func fmt(_ n: Int) -> String { String(n) }

    /// Numeric distractors around the correct answer (questions.ts makeOptions).
    private static func makeOptions(_ correct: Int, count: Int = 4) -> [Int] {
        var opts: Set<Int> = [correct]
        let range = max(5, abs(correct) * 2 + 3)
        var attempts = 0
        while opts.count < count && attempts < 50 {
            let offset = rand(1, range)
            let wrong = correct + (Bool.random() ? offset : -offset)
            opts.insert(wrong)
            attempts += 1
        }
        var fill = correct - 10
        while opts.count < count { opts.insert(fill); fill += 1 }
        return shuffle(Array(opts))
    }

    private static func makeOptions(_ correct: Double, count: Int = 4) -> [Double] {
        let c = Int(correct.rounded())
        return makeOptions(c, count: count).map { Double($0) }
    }

    private static var counter = 0
    private static func qid() -> String {
        counter += 1
        return "q_\(Int(Date().timeIntervalSince1970))_\(counter)"
    }

    /// Guarantee the exact answer string is present among the options
    /// (questions.ts ensureAnswerPresent).
    private static func ensureAnswerPresent(_ q: MathQuestion) -> MathQuestion {
        if q.options.contains(q.answer) { return q }
        var options = q.options
        if options.isEmpty {
            options = [q.answer]
        } else {
            options[options.count - 1] = q.answer
        }
        return MathQuestion(
            id: q.id, topic: q.topic, subtopic: q.subtopic, difficulty: q.difficulty,
            question: q.question, answer: q.answer, options: options,
            timeLimit: q.timeLimit, hint: q.hint, explanation: q.explanation
        )
    }

    private static func question(
        _ topic: MathTopic, _ subtopic: String, _ difficulty: MathDifficulty,
        _ text: String, _ answer: String, _ options: [String],
        extraTime: Int = 0, hint: String, explanation: String
    ) -> MathQuestion {
        MathQuestion(
            id: qid(), topic: topic, subtopic: subtopic, difficulty: difficulty,
            question: text, answer: answer, options: options,
            timeLimit: difficulty.timeLimit + extraTime, hint: hint, explanation: explanation
        )
    }

    // MARK: - Generators (one per topic, questions.ts lines 82–997)

    private static func generate(_ topic: MathTopic, _ diff: MathDifficulty, _ subtopic: String?) -> MathQuestion {
        switch topic {
        case .arithmetic:   return genArithmetic(diff, subtopic)
        case .fractions:    return genFractions(diff)
        case .decimals:     return genDecimals(diff)
        case .percentages:  return genPercentages(diff)
        case .ratios:       return genRatios(diff)
        case .preAlgebra:   return genPreAlgebra(diff)
        case .algebra1:     return genAlgebra1(diff, subtopic)
        case .algebra2:     return genAlgebra2(diff, subtopic)
        case .geometry:     return genGeometry(diff, subtopic)
        case .trigonometry: return genTrigonometry(diff, subtopic)
        case .precalculus:  return genPrecalculus(diff, subtopic)
        case .calculus:     return genCalculus(diff, subtopic)
        case .statistics:   return genStatistics(diff, subtopic)
        }
    }

    // MARK: Arithmetic

    private static func genArithmetic(_ diff: MathDifficulty, _ subtopic: String?) -> MathQuestion {
        let sub = subtopic ?? pick(["addition", "subtraction", "multiplication", "division"])
        let r: (min: Int, max: Int) = {
            switch diff {
            case .easy: return (1, 20)
            case .medium: return (2, 50)
            case .hard: return (5, 100)
            case .expert: return (10, 500)
            }
        }()

        switch sub {
        case "addition":
            let a = rand(r.min, r.max), b = rand(r.min, r.max)
            return question(.arithmetic, sub, diff, "What is \(a) + \(b)?", fmt(a + b), makeOptions(a + b).map(fmt),
                hint: "Add the two numbers together.", explanation: "\(a) + \(b) = \(a + b)")
        case "subtraction":
            let a = rand(r.min, r.max), b = rand(r.min, max(r.min, a))
            return question(.arithmetic, sub, diff, "What is \(a) − \(b)?", fmt(a - b), makeOptions(a - b).map(fmt),
                hint: "Subtract the second number from the first.", explanation: "\(a) − \(b) = \(a - b)")
        case "multiplication":
            let (aRange, bRange): (ClosedRange<Int>, ClosedRange<Int>) = {
                switch diff {
                case .easy: return (1...10, 1...10)
                case .medium: return (2...12, 2...12)
                case .hard: return (5...20, 5...20)
                case .expert: return (10...50, 10...25)
                }
            }()
            let a = rand(aRange.lowerBound, aRange.upperBound)
            let b = rand(bRange.lowerBound, bRange.upperBound)
            return question(.arithmetic, sub, diff, "What is \(a) × \(b)?", fmt(a * b), makeOptions(a * b).map(fmt),
                hint: "Multiply the two numbers.", explanation: "\(a) × \(b) = \(a * b)")
        case "division":
            let bMax = diff == .easy ? 10 : diff == .medium ? 12 : diff == .hard ? 20 : 25
            let ansMax = diff == .easy ? 10 : diff == .medium ? 15 : diff == .hard ? 25 : 50
            let b = rand(2, bMax)
            let answer = rand(2, ansMax)
            let a = b * answer
            return question(.arithmetic, sub, diff, "What is \(a) ÷ \(b)?", fmt(answer), makeOptions(answer).map(fmt),
                hint: "Think: what times \(b) equals \(a)?", explanation: "\(a) ÷ \(b) = \(answer)")
        default:
            return genArithmetic(diff, "addition")
        }
    }

    // MARK: Fractions

    private static func genFractions(_ diff: MathDifficulty) -> MathQuestion {
        let denoms: [Int] = {
            switch diff {
            case .easy: return [2, 3, 4, 5, 6]
            case .medium: return [2, 3, 4, 5, 6, 8, 10]
            case .hard: return [2, 3, 4, 5, 6, 8, 9, 10, 12]
            case .expert: return [3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
            }
        }()

        if diff == .easy || (diff == .medium && Bool.random()) {
            let d = pick(denoms)
            let n1 = rand(1, d - 1), n2 = rand(1, d - 1)
            let sumN = n1 + n2
            let ans = sumN > d ? "\(sumN / d) \(sumN % d)/\(d)" : "\(sumN)/\(d)"
            let numAns = Double(sumN) / Double(d)
            return question(
                .fractions, "fractions", diff,
                "What is \(n1)/\(d) + \(n2)/\(d)?", ans,
                makeOptions((numAns * 100).rounded() / 100).map { fmt($0 / 100) },
                extraTime: 10,
                hint: "Add the numerators, keep the denominator the same.",
                explanation: "\(n1)/\(d) + \(n2)/\(d) = \(sumN)/\(d)" + (sumN > d ? " = \(ans)" : "")
            )
        }

        let d1 = pick(denoms)
        let n1 = rand(1, d1 - 1)
        let g = gcd(n1, d1)
        let simplified = "\(n1 / g)/\(d1 / g)"
        let options = shuffle([simplified, "\(n1 * 2)/\(d1 * 2)", "\(n1)/\(d1 * 2)", "\(n1 + 1)/\(d1)"])
        return question(
            .fractions, "fractions", diff,
            "Simplify \(n1)/\(d1).", simplified, options,
            extraTime: 10,
            hint: "Find the greatest common divisor of numerator and denominator.",
            explanation: "GCD(\(n1), \(d1)) = \(g), so \(n1)/\(d1) = \(n1 / g)/\(d1 / g) = \(simplified)"
        )
    }

    // MARK: Decimals

    private static func genDecimals(_ diff: MathDifficulty) -> MathQuestion {
        let places = diff == .easy ? 1 : 2
        let scale = pow(10.0, Double(places))
        let a = (Double(rand(10, 100)) / scale * scale).rounded() / scale
        let b = (Double(rand(10, 100)) / scale * scale).rounded() / scale
        let plus = pick(["+", "−"]) == "+"
        let answer = plus ? (a + b) : (a - b)
        let op = plus ? "+" : "−"
        return question(
            .decimals, "decimals", diff,
            "What is \(fmt(a)) \(op) \(fmt(b))?", fmt(answer),
            makeOptions((answer * 100).rounded()).map { fmt($0 / 100) },
            extraTime: 5,
            hint: "Line up the decimal points before adding/subtracting.",
            explanation: "\(fmt(a)) \(op) \(fmt(b)) = \(fmt(answer))"
        )
    }

    // MARK: Percentages

    private static func genPercentages(_ diff: MathDifficulty) -> MathQuestion {
        let percent = rand(1, diff == .easy ? 50 : diff == .medium ? 100 : 200)
        let whole = rand(10, diff == .easy ? 100 : 500)
        let answer = (Double(percent) / 100.0 * Double(whole) * 100).rounded() / 100
        return question(
            .percentages, "percentages", diff,
            "What is \(percent)% of \(whole)?", fmt(answer),
            makeOptions((answer * 10).rounded() / 10).map { fmt($0) },
            extraTime: 5,
            hint: "Convert percentage to decimal, then multiply.",
            explanation: "\(percent)% × \(whole) = \(fmt(Double(percent) / 100.0)) × \(whole) = \(fmt(answer))"
        )
    }

    // MARK: Ratios

    private static func genRatios(_ diff: MathDifficulty) -> MathQuestion {
        if diff == .easy || Bool.random() {
            let a = rand(2, 8), b = rand(2, 8), mult = rand(2, 5)
            let x = a * mult
            let answer = b * mult
            return question(
                .ratios, "ratios", diff,
                "If the ratio is \(a):\(b) and one value is \(x), what is the other?",
                fmt(answer), makeOptions(answer).map(fmt),
                extraTime: 5,
                hint: "Find the multiplier: \(x) / \(a) = \(mult). Then multiply \(b) by \(mult).",
                explanation: "\(a):\(b) scaled by \(mult) = \(x):\(answer)"
            )
        }
        let a = rand(2, 10), b = rand(2, 10), c = rand(2, 10)
        let d = Double(b * c) / Double(a)
        return question(
            .ratios, "proportions", diff,
            "Solve for x: \(a)/\(b) = \(c)/x", fmt(d),
            makeOptions(Double(Int(d.rounded()))).map { fmt($0) },
            extraTime: 5,
            hint: "Cross multiply: a × x = b × c, then solve for x.",
            explanation: "\(a) × x = \(b) × \(c) → x = \(b * c) / \(a) = \(fmt(d))"
        )
    }

    // MARK: Pre-Algebra

    private static func genPreAlgebra(_ diff: MathDifficulty) -> MathQuestion {
        let x = rand(1, diff == .easy ? 10 : 20)
        let a = rand(1, diff == .easy ? 5 : 10)
        let b = rand(0, diff == .easy ? 10 : 20)
        let c = a * x + b
        return question(
            .preAlgebra, "integers", diff,
            "Solve for x: \(a)x + \(b) = \(c)", fmt(x), makeOptions(x).map(fmt),
            extraTime: 10,
            hint: "Subtract the constant, then divide by the coefficient of x.",
            explanation: "\(a)x + \(b) = \(c) → \(a)x = \(c - b) → x = \(c - b) / \(a) = \(x)"
        )
    }

    // MARK: Algebra 1

    private static func genAlgebra1(_ diff: MathDifficulty, _ subtopic: String?) -> MathQuestion {
        let sub = subtopic ?? pick(["variables", "equations", "systems", "inequalities"])

        if sub == "variables" || sub == "expressions" {
            let x = rand(-5, 5), a = rand(1, 5), b = rand(-5, 5)
            let (expr, answer): (String, Int) = diff == .easy
                ? ("\(a)x + \(b)", a * x + b)
                : ("\(a)x² + \(b)x", a * x * x + b * x)
            return question(
                .algebra1, sub, diff,
                "Evaluate \(expr) when x = \(x).", fmt(answer), makeOptions(answer).map(fmt),
                extraTime: 5,
                hint: "Substitute the value of x into the expression.",
                explanation: "When x = \(x): \(expr) = \(answer)"
            )
        }

        if sub == "equations" || sub == "linear-equations" {
            let x = rand(-10, 10), a = rand(2, 8), b = rand(-10, 10)
            let c = a * x + b
            return question(
                .algebra1, sub, diff,
                "Solve: \(a)x + \(b) = \(c)", fmt(x), makeOptions(x).map(fmt),
                extraTime: 5,
                hint: "Isolate x: subtract the constant, divide by the coefficient.",
                explanation: "\(a)x = \(c) - \(b) = \(c - b), x = \(c - b) / \(a) = \(x)"
            )
        }

        if sub == "systems" {
            let x = rand(-6, 8), y = rand(-6, 8)
            let a1 = rand(1, 5), b1 = rand(1, 5), c1 = a1 * x + b1 * y
            let a2 = rand(1, 5), b2 = rand(1, 5), c2 = a2 * x + b2 * y
            return question(
                .algebra1, sub, diff,
                "Solve the system for x:\n  \(a1)x + \(b1)y = \(c1)\n  \(a2)x + \(b2)y = \(c2)",
                fmt(x), makeOptions(x).map(fmt),
                extraTime: 15,
                hint: "Multiply each equation to match a coefficient, then subtract to eliminate a variable.",
                explanation: "The solution is x = \(x), y = \(y) (it satisfies both equations)."
            )
        }

        // inequalities
        let x = rand(-8, 8), a = rand(2, 6), b = rand(-8, 8)
        let strict = Bool.random()
        let op = strict ? "<" : "≤"
        let c = a * x + b
        return question(
            .algebra1, sub, diff,
            "Solve for x: \(a)x + \(b) \(op) \(c). What is the boundary value?",
            fmt(x), makeOptions(x).map(fmt),
            extraTime: 8,
            hint: "Solve like an equation: \(a)x \(op) \(c - b). Dividing by a positive keeps the sign.",
            explanation: "\(a)x \(op) \(c - b) → x \(op) \(fmt(Double(c - b) / Double(a))) = \(x), so the solution is x \(op) \(x)."
        )
    }

    // MARK: Algebra 2

    private static func genAlgebra2(_ diff: MathDifficulty, _ subtopic: String?) -> MathQuestion {
        let sub = subtopic ?? pick(["quadratics", "polynomials", "functions", "logarithms"])

        if sub == "quadratics" {
            let r1 = rand(-5, 5), r2 = rand(-5, 5)
            let b = -(r1 + r2)
            let c = r1 * r2
            let bStr = b >= 0 ? "+ \(b)" : "− \(abs(b))"
            let cStr = c >= 0 ? "+ \(c)" : "− \(abs(c))"
            let answer = pick([r1, r2])
            return question(
                .algebra2, sub, diff,
                "What is a root of x² \(bStr)x \(cStr) = 0?", fmt(answer), makeOptions(answer).map(fmt),
                extraTime: 10,
                hint: "Factor the quadratic or use the quadratic formula.",
                explanation: "The roots are \(r1) and \(r2) (sum = \(r1 + r2), product = \(c))"
            )
        }

        if sub == "polynomials" {
            let mode = pick(["add", "multiply"])
            if mode == "add" {
                let a = rand(1, 6), b = rand(-4, 4), c = rand(1, 6), d = rand(-4, 4)
                let ra = a + c, rb = b + d
                let answer = "\(ra)x \(rb >= 0 ? "+ \(rb)" : "− \(abs(rb))")"
                let aStr = b >= 0 ? "+ \(b)" : "− \(abs(b))"
                let cStr = d >= 0 ? "+ \(d)" : "− \(abs(d))"
                let rbStr = rb >= 0 ? "+ \(rb)" : "− \(abs(rb))"
                let rb2Str = rb + 2 >= 0 ? "+ \(rb + 2)" : "− \(abs(rb + 2))"
                let options = shuffle([
                    answer,
                    "\(ra + 1)x \(rbStr)",
                    "\(a * c)x² \(rbStr)",
                    "\(ra)x \(rb2Str)",
                ])
                return question(
                    .algebra2, sub, diff,
                    "Simplify: (\(a)x \(aStr)) + (\(c)x \(cStr))", answer, options,
                    extraTime: 8,
                    hint: "Combine like terms — add the x coefficients and the constants separately.",
                    explanation: "(\(a)x + \(c)x) + (\(b) \(d >= 0 ? "+" : "−") \(abs(d))) = \(ra)x \(rb >= 0 ? "+" : "−") \(abs(rb))"
                )
            }
            let a = rand(1, 4), b = rand(-3, 3), c = rand(1, 4), d = rand(-3, 3)
            let x2 = a * c, x1 = a * d + b * c, x0 = b * d
            let answer = "\(x2)x² \(x1 >= 0 ? "+ \(x1)" : "− \(abs(x1))")x \(x0 >= 0 ? "+ \(x0)" : "− \(abs(x0))")"
            let aStr = b >= 0 ? "+ \(b)" : "− \(abs(b))"
            let cStr = d >= 0 ? "+ \(d)" : "− \(abs(d))"
            let options = shuffle([
                answer,
                "\(x2)x² \(x1 + 1 >= 0 ? "+ \(x1 + 1)" : "− \(abs(x1 + 1))")x \(x0 >= 0 ? "+ \(x0)" : "− \(abs(x0))")",
                "\(x2 + 1)x² \(x1 >= 0 ? "+ \(x1)" : "− \(abs(x1))")x \(x0 >= 0 ? "+ \(x0)" : "− \(abs(x0))")",
                "\(x2)x² \(x1 >= 0 ? "+ \(x1)" : "− \(abs(x1))")x \(x0 + 2 >= 0 ? "+ \(x0 + 2)" : "− \(abs(x0 + 2))")",
            ])
            return question(
                .algebra2, sub, diff,
                "Expand: (\(a)x \(aStr))(\(c)x \(cStr))", answer, options,
                extraTime: 12,
                hint: "Use FOIL: multiply First, Outer, Inner, Last terms, then combine like terms.",
                explanation: "FOIL: \(a * c)x² + \(a * d)x + \(b * c)x + \(b * d) = \(answer)"
            )
        }

        if sub == "functions" {
            let x = rand(-4, 6), a = rand(1, 4), b = rand(-3, 5)
            let fx = a * x + b
            let bStr = b >= 0 ? "+ \(b)" : "− \(abs(b))"
            return question(
                .algebra2, sub, diff,
                "If f(x) = \(a)x \(bStr), find f(\(x)).", fmt(fx), makeOptions(fx).map(fmt),
                extraTime: 6,
                hint: "Substitute \(x) for x in the function and evaluate.",
                explanation: "f(\(x)) = \(a)(\(x)) \(b >= 0 ? "+" : "−") \(abs(b)) = \(a * x) \(b >= 0 ? "+" : "−") \(abs(b)) = \(fx)"
            )
        }

        // logarithms
        let base = pick([2, 3, 5, 10])
        let k = rand(2, diff == .easy ? 4 : 6)
        let value = Int(pow(Double(base), Double(k)))
        return question(
            .algebra2, sub, diff,
            "Evaluate log\(base)(\(value)).", fmt(k), makeOptions(k).map(fmt),
            extraTime: 10,
            hint: "Ask: \(base) to what power equals \(value)?",
            explanation: "log\(base)(\(value)) = \(k), because \(base)^\(k) = \(value)"
        )
    }

    // MARK: Geometry

    private static func genGeometry(_ diff: MathDifficulty, _ subtopic: String?) -> MathQuestion {
        let sub = subtopic ?? pick(["angles", "triangles", "circles", "area", "volume", "coordinate"])

        if sub == "area" {
            let type = pick(["rectangle", "triangle", "circle"])
            if type == "rectangle" {
                let l = rand(3, 15), w = rand(3, 15)
                return question(
                    .geometry, sub, diff,
                    "Find the area of a rectangle with length \(l) and width \(w).",
                    fmt(l * w), makeOptions(l * w).map(fmt),
                    hint: "Area = length × width", explanation: "A = \(l) × \(w) = \(l * w)"
                )
            }
            if type == "triangle" {
                let b = rand(4, 16), h = rand(4, 16)
                let a = (b * h) / 2
                return question(
                    .geometry, sub, diff,
                    "Find the area of a triangle with base \(b) and height \(h).",
                    fmt(a), makeOptions(a).map(fmt),
                    extraTime: 5,
                    hint: "Area = ½ × base × height", explanation: "A = ½ × \(b) × \(h) = \(a)"
                )
            }
            let r = rand(2, 10)
            let a = (Double.pi * Double(r * r) * 100).rounded() / 100
            return question(
                .geometry, sub, diff,
                "Find the area of a circle with radius \(r). (Use π ≈ 3.14)",
                fmt(a), makeOptions(Double(Int(a.rounded()))).map { fmt($0) },
                extraTime: 5,
                hint: "Area = π × r²", explanation: "A = π × \(r)² ≈ \(fmt(a))"
            )
        }

        if sub == "volume" {
            if pick(["cube", "rectangular-prism"]) == "cube" {
                let s = rand(2, 10)
                return question(
                    .geometry, sub, diff,
                    "Find the volume of a cube with side \(s).",
                    fmt(s * s * s), makeOptions(s * s * s).map(fmt),
                    hint: "Volume = side³", explanation: "V = \(s)³ = \(s * s * s)"
                )
            }
            let l = rand(2, 8), w = rand(2, 8), h = rand(2, 8)
            return question(
                .geometry, sub, diff,
                "Find the volume of a rectangular prism: \(l) × \(w) × \(h).",
                fmt(l * w * h), makeOptions(l * w * h).map(fmt),
                hint: "Volume = length × width × height",
                explanation: "V = \(l) × \(w) × \(h) = \(l * w * h)"
            )
        }

        if sub == "angles" {
            let a = rand(30, 120)
            let comp = 180 - a
            return question(
                .geometry, sub, diff,
                "Two angles are supplementary. One angle is \(a)°. What is the other?",
                fmt(comp), makeOptions(comp).map(fmt),
                hint: "Supplementary angles add to 180°.",
                explanation: "180° − \(a)° = \(comp)°"
            )
        }

        if sub == "coordinate" {
            let x1 = rand(0, 10), y1 = rand(0, 10), x2 = rand(0, 10), y2 = rand(0, 10)
            let dist = ((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
            let d = (sqrt(Double(dist)) * 100).rounded() / 100
            return question(
                .geometry, sub, diff,
                "Find the distance between (\(x1), \(y1)) and (\(x2), \(y2)).",
                fmt(d), makeOptions(Int(d.rounded())).map { fmt($0) },
                extraTime: 10,
                hint: "Use the distance formula: d = √((x₂−x₁)² + (y₂−y₁)²)",
                explanation: "d = √(\(x2 - x1)² + \(y2 - y1)²) = √\(dist) ≈ \(fmt(d))"
            )
        }

        // circles
        let r = rand(3, 12)
        if Bool.random() {
            let a = (Double.pi * Double(r * r) * 100).rounded() / 100
            return question(
                .geometry, sub, diff,
                "Find the area of a circle with radius \(r). (Use π ≈ 3.14)",
                fmt(a), makeOptions(Int(a.rounded())).map { fmt($0) },
                extraTime: 5,
                hint: "Area = π × r²", explanation: "A = π × \(r)² ≈ \(fmt(a))"
            )
        }
        let c = (2 * Double.pi * Double(r) * 100).rounded() / 100
        return question(
            .geometry, sub, diff,
            "Find the circumference of a circle with radius \(r). (Use π ≈ 3.14)",
            fmt(c), makeOptions(Int(c.rounded())).map { fmt($0) },
            extraTime: 5,
            hint: "Circumference = 2 × π × r", explanation: "C = 2 × π × \(r) ≈ \(fmt(c))"
        )
    }

    private static func triangleThirdAngle(_ diff: MathDifficulty, _ subtopic: String) -> MathQuestion {
        let a = rand(40, 80), b = rand(40, 80)
        let c = max(1, 180 - a - b)
        return question(
            .geometry, subtopic, diff,
            "A triangle has angles \(a)° and \(b)°. What is the third angle?",
            fmt(c), makeOptions(c).map(fmt),
            hint: "Angles in a triangle sum to 180°.",
            explanation: "180 − \(a) − \(b) = \(c)°"
        )
    }

    private static func genTrigonometry(_ diff: MathDifficulty, _ subtopic: String?) -> MathQuestion {
        let sub = subtopic ?? pick(["sine-cosine", "identities", "triangles-trig"])

        if sub == "sine-cosine" {
            let angle = pick([30, 45, 60])
            let adj = rand(3, 10)
            if Bool.random() {
                let raw = Double(adj) * tan(Double(angle) * .pi / 180)
                let opp = (diff == .easy ? raw * 10 : raw * 100).rounded() / (diff == .easy ? 10 : 100)
                return question(
                    .trigonometry, sub, diff,
                    "In a right triangle, the adjacent side to \(angle)° is \(adj). Find the opposite side. (Round to 2 decimal places)",
                    fmt(opp), makeOptions(Int(opp.rounded())).map { fmt($0) },
                    extraTime: 15,
                    hint: "tan(\(angle)°) = opposite / adjacent",
                    explanation: "tan(\(angle)°) = opp / \(adj) → opp = \(adj) × tan(\(angle)°) ≈ \(fmt(opp))"
                )
            }
            let hyp = (Double(adj) / cos(Double(angle) * .pi / 180) * 100).rounded() / 100
            return question(
                .trigonometry, sub, diff,
                "In a right triangle, the adjacent side to \(angle)° is \(adj). Find the hypotenuse. (Round to 2 decimal places)",
                fmt(hyp), makeOptions(Int(hyp.rounded())).map { fmt($0) },
                extraTime: 15,
                hint: "cos(\(angle)°) = adjacent / hypotenuse",
                explanation: "cos(\(angle)°) = \(adj) / hyp → hyp = \(adj) / cos(\(angle)°) ≈ \(fmt(hyp))"
            )
        }

        if sub == "identities" {
            let triples: [(a: Int, b: Int, h: Int)] = [(3, 4, 5), (5, 12, 13), (8, 15, 17), (6, 8, 10)]
            let t = pick(triples)
            let sinVal = (Double(t.a) / Double(t.h) * 100).rounded() / 100
            let cosVal = (Double(t.b) / Double(t.h) * 100).rounded() / 100
            if Bool.random() {
                let options = shuffle([sinVal, cosVal, 1 - sinVal, sinVal + 0.1].map { ($0 * 100).rounded() / 100 })
                return question(
                    .trigonometry, sub, diff,
                    "If cos(θ) = \(fmt(cosVal)) and θ is acute, find sin(θ).",
                    fmt(sinVal), options.map { fmt($0) },
                    extraTime: 12,
                    hint: "Use sin²(θ) + cos²(θ) = 1, so sin(θ) = √(1 − cos²(θ)).",
                    explanation: "sin²(θ) = 1 − (\(fmt(cosVal)))² = \(fmt(1 - cosVal * cosVal)), so sin(θ) = \(fmt(sinVal))"
                )
            }
            let options = shuffle([cosVal, sinVal, 1 - cosVal, cosVal + 0.1].map { ($0 * 100).rounded() / 100 })
            return question(
                .trigonometry, sub, diff,
                "If sin(θ) = \(fmt(sinVal)) and θ is acute, find cos(θ).",
                fmt(cosVal), options.map { fmt($0) },
                extraTime: 12,
                hint: "Use sin²(θ) + cos²(θ) = 1, so cos(θ) = √(1 − sin²(θ)).",
                explanation: "cos²(θ) = 1 − (\(fmt(sinVal)))² = \(fmt(1 - sinVal * sinVal)), so cos(θ) = \(fmt(cosVal))"
            )
        }

        // triangles-trig
        let angle = pick([30, 45, 60])
        let hyp = rand(5, 15)
        let useSin = Bool.random()
        let ratio = useSin
            ? sin(Double(angle) * .pi / 180)
            : cos(Double(angle) * .pi / 180)
        let leg = (Double(hyp) * ratio * 100).rounded() / 100
        let which = useSin ? "opposite" : "adjacent"
        let fn = useSin ? "sin" : "cos"
        return question(
            .trigonometry, sub, diff,
            "In a right triangle, the hypotenuse is \(hyp) and one angle is \(angle)°. Find the \(which) side. (Round to 2 decimal places)",
            fmt(leg), makeOptions(Int(leg.rounded())).map { fmt($0) },
            extraTime: 15,
            hint: "\(fn)(\(angle)°) = \(which) / hypotenuse",
            explanation: "\(fn)(\(angle)°) = \(which) / \(hyp) → \(which) = \(hyp) × \(fn)(\(angle)°) ≈ \(fmt(leg))"
        )
    }

    // MARK: Precalculus

    private static func genPrecalculus(_ diff: MathDifficulty, _ subtopic: String?) -> MathQuestion {
        let sub = subtopic ?? pick(["sequences", "complex-numbers", "limits-intro"])

        if sub == "sequences" {
            let start = rand(1, 10), d = rand(2, 5), n = rand(5, 10)
            let nth = start + (n - 1) * d
            return question(
                .precalculus, sub, diff,
                "Find the \(n)th term of the arithmetic sequence: \(start), \(start + d), \(start + 2 * d), ...",
                fmt(nth), makeOptions(nth).map(fmt),
                extraTime: 10,
                hint: "aₙ = a₁ + (n−1)d where a₁ = \(start), d = \(d)",
                explanation: "a\(n) = \(start) + (\(n)−1) × \(d) = \(nth)"
            )
        }

        if sub == "complex-numbers" {
            let a = rand(1, 5), b = rand(1, 5), c = rand(1, 5), d2 = rand(1, 5)
            let real = a + c, imag = b + d2
            let answer = "\(real) + \(imag)i"
            let options = shuffle([answer, "\(real) - \(imag)i", "\(real + imag)i", "\(real - imag)i"])
            return question(
                .precalculus, sub, diff,
                "What is (\(a) + \(b)i) + (\(c) + \(d2)i)?", answer, options,
                extraTime: 5,
                hint: "Add real parts and imaginary parts separately.",
                explanation: "(\(a) + \(c)) + (\(b) + \(d2))i = \(real) + \(imag)i"
            )
        }

        // limits-intro
        if diff != .easy && Bool.random() {
            let a = rand(2, 6)
            let answer = 2 * a
            return question(
                .precalculus, sub, diff,
                "Evaluate lim(x→\(a)) (x² − \(a * a)) / (x − \(a)).",
                fmt(answer), makeOptions(answer).map(fmt),
                extraTime: 12,
                hint: "Factor x² − \(a * a) = (x − \(a))(x + \(a)), then cancel (x − \(a)).",
                explanation: "(x² − \(a * a)) / (x − \(a)) = (x + \(a)) → at x = \(a): \(a) + \(a) = \(answer)"
            )
        }
        let a = rand(1, 5), c1 = rand(1, 4), c0 = rand(-3, 6)
        let answer = c1 * a + c0
        let c0Str = c0 >= 0 ? "+ \(c0)" : "− \(abs(c0))"
        return question(
            .precalculus, sub, diff,
            "Evaluate lim(x→\(a)) (\(c1)x \(c0Str)).",
            fmt(answer), makeOptions(answer).map(fmt),
            extraTime: 6,
            hint: "Polynomials are continuous — just substitute the value.",
            explanation: "\(c1)(\(a)) \(c0 >= 0 ? "+" : "−") \(abs(c0)) = \(c1 * a) \(c0 >= 0 ? "+" : "−") \(abs(c0)) = \(answer)"
        )
    }

    // MARK: Calculus

    private static func genCalculus(_ diff: MathDifficulty, _ subtopic: String?) -> MathQuestion {
        let sub = subtopic ?? pick(["derivatives", "integrals", "limits"])

        if sub == "derivatives" {
            let a = rand(1, 5), n = rand(2, 4)
            let coeff = a * n
            let newN = n - 1
            let answer = "\(coeff)x\(newN > 1 ? "^\(newN)" : "")"
            let options = shuffle([
                answer,
                "\(a)x\(n + 1 > 1 ? "^\(n + 1)" : "")",
                "\(coeff + 1)x\(newN > 1 ? "^\(newN)" : "")",
                "\(a)x\(newN > 1 ? "^\(newN)" : "")",
            ])
            return question(
                .calculus, sub, diff,
                "What is the derivative of f(x) = \(a)x\(n > 1 ? "^\(n)" : "")?", answer, options,
                extraTime: 10,
                hint: "Use the power rule: d/dx[axⁿ] = anxⁿ⁻¹",
                explanation: "d/dx[\(a)x^\(n)] = \(a) × \(n) × x^\(newN) = \(answer)"
            )
        }

        if sub == "integrals" {
            let n = rand(1, 3)
            let aClean = (n + 1) * rand(1, 3)
            let coeff = aClean / (n + 1)
            let newN = n + 1
            let answer = "\(coeff)x\(newN > 1 ? "^\(newN)" : "") + C"
            let options = shuffle([
                answer,
                "\(coeff + 1)x\(newN > 1 ? "^\(newN)" : "") + C",
                "\(aClean)x\(newN > 1 ? "^\(newN)" : "") + C",
                "\(coeff)x\(n > 1 ? "^\(n)" : "") + C",
            ])
            return question(
                .calculus, sub, diff,
                "Evaluate ∫ \(aClean)x\(n > 1 ? "^\(n)" : "") dx.", answer, options,
                extraTime: 12,
                hint: "Use the power rule: ∫axⁿ dx = a/(n+1) · xⁿ⁺¹ + C",
                explanation: "∫ \(aClean)x^\(n) dx = \(aClean)/\(n + 1) · x^\(newN) + C = \(answer)"
            )
        }

        // limits
        if Bool.random() {
            let a = rand(1, 5), c = rand(1, 5), b = rand(-3, 3), d = rand(-3, 3)
            let answer = Double(a) / Double(c)
            let bStr = b >= 0 ? "+ \(b)" : "− \(abs(b))"
            let dStr = d >= 0 ? "+ \(d)" : "− \(abs(d))"
            return question(
                .calculus, sub, diff,
                "Evaluate lim(x→∞) (\(a)x \(bStr)) / (\(c)x \(dStr)).",
                fmt(answer), makeOptions(Double(Int((answer * 100).rounded() / 100))).map { fmt($0) },
                extraTime: 12,
                hint: "For limits at infinity of rationals, compare leading coefficients.",
                explanation: "Leading coefficients: \(a)/\(c) = \(fmt(answer))"
            )
        }
        let a = rand(1, 5), n = rand(2, 3), x0 = rand(1, 4)
        let answer = a * Int(pow(Double(x0), Double(n)))
        return question(
            .calculus, sub, diff,
            "Evaluate lim(x→\(x0)) \(a)x\(n > 1 ? "^\(n)" : "").",
            fmt(answer), makeOptions(answer).map(fmt),
            extraTime: 8,
            hint: "Polynomials are continuous — substitute directly.",
            explanation: "\(a) × \(x0)^\(n) = \(answer)"
        )
    }

    // MARK: Statistics

    private static func genStatistics(_ diff: MathDifficulty, _ subtopic: String?) -> MathQuestion {
        let sub = subtopic ?? pick(["mean-median", "probability", "distributions"])

        if sub == "mean-median" {
            let count = diff == .easy ? 4 : diff == .medium ? 5 : 6
            let nums = (0..<count).map { _ in rand(1, 20) }
            let mean = Double(nums.reduce(0, +)) / Double(count)
            let sorted = nums.sorted()
            let median: Double = count % 2 == 0
                ? Double(sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
                : Double(sorted[count / 2])
            if Bool.random() {
                return question(
                    .statistics, sub, diff,
                    "Find the mean of: \(nums.map(String.init).joined(separator: ", "))",
                    fmt((mean * 100).rounded() / 100), makeOptions(Int(mean.rounded())).map { fmt($0) },
                    extraTime: 5,
                    hint: "Mean = sum of all values ÷ count",
                    explanation: "(\(nums.map(String.init).joined(separator: " + "))) / \(count) = \(fmt((mean * 100).rounded() / 100))"
                )
            }
            return question(
                .statistics, sub, diff,
                "Find the median of: \(nums.map(String.init).joined(separator: ", "))",
                fmt(median), makeOptions(Int(median.rounded())).map { fmt($0) },
                extraTime: 5,
                hint: "Sort the numbers, then find the middle value.",
                explanation: "Sorted: \(sorted.map(String.init).joined(separator: ", ")). Median = \(fmt(median))"
            )
        }

        if sub == "probability" {
            if pick(["bag", "die"]) == "bag" {
                let total = rand(8, 20)
                let target = rand(2, max(3, total - 2))
                let p = (Double(target) / Double(total) * 100).rounded() / 100
                let color = pick(["red", "blue", "green", "yellow"])
                return question(
                    .statistics, sub, diff,
                    "A bag has \(target) \(color) marbles out of \(total) total. What's the probability of drawing a \(color) marble? (Round to 2 decimal places)",
                    fmt(p), makeOptions(Int((p * 100).rounded() / 100)).map { fmt($0) },
                    extraTime: 8,
                    hint: "Probability = (favorable outcomes) ÷ (total outcomes).",
                    explanation: "P(\(color)) = \(target)/\(total) = \(fmt(p))"
                )
            }
            let target = pick([
                (label: "an even number", count: 3),
                (label: "a number greater than 4", count: 2),
                (label: "a multiple of 3", count: 2),
            ])
            let p = (Double(target.count) / 6.0 * 100).rounded() / 100
            return question(
                .statistics, sub, diff,
                "A fair 6-sided die is rolled. What's the probability of rolling \(target.label)? (Round to 2 decimal places)",
                fmt(p), makeOptions(Int((p * 100).rounded() / 100)).map { fmt($0) },
                extraTime: 8,
                hint: "Count favorable outcomes ÷ 6 total outcomes.",
                explanation: "Favorable: \(target.count). P = \(target.count)/6 = \(fmt(p))"
            )
        }

        // distributions
        if pick(["expected-die", "weighted"]) == "expected-die" {
            return question(
                .statistics, sub, diff,
                "What is the expected value of rolling a fair 6-sided die?",
                "3.5", makeOptions(3.5).map { fmt($0) },
                extraTime: 10,
                hint: "E(X) = Σ x · P(x) = (1+2+3+4+5+6)/6.",
                explanation: "E(X) = (1+2+3+4+5+6) / 6 = 21/6 = 3.5"
            )
        }
        let v1 = rand(2, 8), v2 = rand(2, 8), w1 = rand(1, 4), w2 = rand(1, 4)
        let ev = (Double(v1 * w1 + v2 * w2) / Double(w1 + w2) * 100).rounded() / 100
        return question(
            .statistics, sub, diff,
            "A weighted distribution has value \(v1) with weight \(w1) and value \(v2) with weight \(w2). Find the expected value. (Round to 2 decimal places)",
            fmt(ev), makeOptions(Int((ev * 100).rounded() / 100)).map { fmt($0) },
            extraTime: 12,
            hint: "E(X) = Σ (value × weight) ÷ Σ weights.",
            explanation: "(\(v1)×\(w1) + \(v2)×\(w2)) / (\(w1)+\(w2)) = \(v1 * w1 + v2 * w2) / \(w1 + w2) = \(fmt(ev))"
        )
    }
}

// MARK: End of question engine
