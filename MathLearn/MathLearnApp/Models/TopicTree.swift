//
//  TopicTree.swift
//  MathLearn
//
//  Direct port of TOPIC_TREE (src/lib/math/topics.ts) — the 9 practice
//  subjects with their subtopics, each mapped to the generator topics.
//

import Foundation

enum TopicTree {
    static let all: [TopicInfo] = [
        TopicInfo(
            key: "arithmetic", label: "Arithmetic", blurb: "Add, subtract, multiply & divide",
            grades: ["K–2", "3–5"], icon: "➕", color: "mint",
            subtopics: [
                SubtopicInfo(key: "addition", label: "Addition", mathTopics: [.arithmetic]),
                SubtopicInfo(key: "subtraction", label: "Subtraction", mathTopics: [.arithmetic]),
                SubtopicInfo(key: "multiplication", label: "Multiplication", mathTopics: [.arithmetic]),
                SubtopicInfo(key: "division", label: "Division", mathTopics: [.arithmetic]),
            ]
        ),
        TopicInfo(
            key: "pre-algebra", label: "Pre-Algebra", blurb: "Fractions, decimals, percents & ratios",
            grades: ["6–7"], icon: "🔢", color: "blue",
            subtopics: [
                SubtopicInfo(key: "fractions", label: "Fractions", mathTopics: [.fractions]),
                SubtopicInfo(key: "decimals", label: "Decimals", mathTopics: [.decimals]),
                SubtopicInfo(key: "percentages", label: "Percentages", mathTopics: [.percentages]),
                SubtopicInfo(key: "ratios", label: "Ratios & Proportions", mathTopics: [.ratios]),
                SubtopicInfo(key: "integers", label: "Integers", mathTopics: [.preAlgebra]),
            ]
        ),
        TopicInfo(
            key: "algebra-1", label: "Algebra 1", blurb: "Variables, equations & inequalities",
            grades: ["8–9"], icon: "✖️", color: "yellow",
            subtopics: [
                SubtopicInfo(key: "variables", label: "Variables & Expressions", mathTopics: [.algebra1]),
                SubtopicInfo(key: "equations", label: "Linear Equations", mathTopics: [.algebra1]),
                SubtopicInfo(key: "systems", label: "Systems of Equations", mathTopics: [.algebra1]),
                SubtopicInfo(key: "inequalities", label: "Inequalities", mathTopics: [.algebra1]),
            ]
        ),
        TopicInfo(
            key: "geometry", label: "Geometry", blurb: "Angles, shapes, area & volume",
            grades: ["9–10"], icon: "📐", color: "purple",
            subtopics: [
                SubtopicInfo(key: "angles", label: "Angles", mathTopics: [.geometry]),
                SubtopicInfo(key: "triangles", label: "Triangles", mathTopics: [.geometry]),
                SubtopicInfo(key: "circles", label: "Circles", mathTopics: [.geometry]),
                SubtopicInfo(key: "area", label: "Area & Perimeter", mathTopics: [.geometry]),
                SubtopicInfo(key: "volume", label: "Volume", mathTopics: [.geometry]),
                SubtopicInfo(key: "coordinate", label: "Coordinate Geometry", mathTopics: [.geometry]),
            ]
        ),
        TopicInfo(
            key: "algebra-2", label: "Algebra 2", blurb: "Quadratics, polynomials & functions",
            grades: ["10–11"], icon: "📈", color: "coral",
            subtopics: [
                SubtopicInfo(key: "quadratics", label: "Quadratics", mathTopics: [.algebra2]),
                SubtopicInfo(key: "polynomials", label: "Polynomials", mathTopics: [.algebra2]),
                SubtopicInfo(key: "functions", label: "Functions", mathTopics: [.algebra2]),
                SubtopicInfo(key: "logarithms", label: "Logarithms", mathTopics: [.algebra2]),
            ]
        ),
        TopicInfo(
            key: "trigonometry", label: "Trigonometry", blurb: "Sine, cosine & identities",
            grades: ["11"], icon: "📊", color: "blue",
            subtopics: [
                SubtopicInfo(key: "sine-cosine", label: "Sine & Cosine", mathTopics: [.trigonometry]),
                SubtopicInfo(key: "identities", label: "Trig Identities", mathTopics: [.trigonometry]),
                SubtopicInfo(key: "triangles-trig", label: "Triangles", mathTopics: [.trigonometry]),
            ]
        ),
        TopicInfo(
            key: "precalculus", label: "Precalculus", blurb: "Sequences, series & complex numbers",
            grades: ["11–12"], icon: "🧮", color: "yellow",
            subtopics: [
                SubtopicInfo(key: "limits-intro", label: "Limits Intro", mathTopics: [.precalculus]),
                SubtopicInfo(key: "sequences", label: "Sequences & Series", mathTopics: [.precalculus]),
                SubtopicInfo(key: "complex-numbers", label: "Complex Numbers", mathTopics: [.precalculus]),
            ]
        ),
        TopicInfo(
            key: "calculus", label: "Calculus", blurb: "Derivatives, integrals & limits",
            grades: ["12"], icon: "∫", color: "purple",
            subtopics: [
                SubtopicInfo(key: "derivatives", label: "Derivatives", mathTopics: [.calculus]),
                SubtopicInfo(key: "integrals", label: "Integrals", mathTopics: [.calculus]),
                SubtopicInfo(key: "limits", label: "Limits", mathTopics: [.calculus]),
            ]
        ),
        TopicInfo(
            key: "statistics", label: "Statistics", blurb: "Mean, median, probability & distributions",
            grades: ["11–12"], icon: "🎲", color: "mint",
            subtopics: [
                SubtopicInfo(key: "mean-median", label: "Mean & Median", mathTopics: [.statistics]),
                SubtopicInfo(key: "probability", label: "Probability", mathTopics: [.statistics]),
                SubtopicInfo(key: "distributions", label: "Distributions", mathTopics: [.statistics]),
            ]
        ),
    ]

    static func subject(forKey key: String) -> TopicInfo? {
        all.first { $0.key == key }
    }
}
