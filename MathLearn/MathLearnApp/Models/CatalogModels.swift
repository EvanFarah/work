//
//  CatalogModels.swift
//  MathLearn
//
//  Course catalog + lesson documents + verified video catalog.
//  Mirrors public/lessons/index.json, courses/<slug>.json (RawLesson)
//  and the import pipeline's ImportedVideo export (videos.json).
//

import Foundation

// MARK: - Course index (public/lessons/index.json)

struct CourseIndex: Codable {
    var courses: [CourseIndexEntry]
}

struct CourseIndexEntry: Codable, Identifiable, Hashable {
    var name: String
    var slug: String
    var icon: String
    var color: String          // hex, from the web index
    var gradient: String
    var description: String
    var gradeBand: String
    var topic: String
    var lessonCount: Int
    var units: [IndexUnit]

    var id: String { slug }
}

struct IndexUnit: Codable, Hashable {
    var name: String
    var lessons: [IndexLesson]
}

struct IndexLesson: Codable, Hashable, Identifiable {
    var title: String
    var description: String

    var id: String { title }
}

// MARK: - Course document (courses/<slug>.json → RawLesson fields)

struct CourseDocument: Codable {
    var name: String
    var units: [CourseUnit]
}

struct CourseUnit: Codable, Hashable {
    var name: String
    var lessons: [LessonDocument]
}

struct LessonDocument: Codable, Identifiable, Hashable {
    var title: String
    var description: String
    var svg: String?
    var vocabulary: [String]?
    var formula: String?
    var content: String?          // HTML string (rendered via AttributedString)
    var steps: [String]?
    var examples: [LessonExample]?
    var tip: String?
    var quiz: [LessonQuizItem]?

    var id: String { title }

    var slug: String { LessonDocument.slugify(title) }

    static func slugify(_ s: String) -> String {
        let lowered = s.lowercased()
        var out = ""
        var lastDash = false
        for ch in lowered {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
                lastDash = false
            } else if !lastDash {
                out.append("-")
                lastDash = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out
    }
}

struct LessonExample: Codable, Hashable {
    var problem: String
    var answer: String
    var work: String?
}

struct LessonQuizItem: Codable, Hashable {
    var question: String
    var answer: String
}

// MARK: - Verified video catalog (import pipeline export)

struct VideoCatalog: Codable {
    var exportedAt: String
    var count: Int
    var videos: [VideoEntry]
}

struct VideoEntry: Codable, Identifiable, Hashable {
    var youtubeId: String
    var title: String
    var durationSeconds: Int
    var author: String
    var publisher: String
    var license: String
    var licenseUrl: String
    var originalVideoUrl: String
    var course: String
    var unit: String
    var topic: String
    var hasNotes: Bool
    var notes: String        // JSON string: [{"text": "..."}]
    var status: String

    var id: String { youtubeId }

    /// Parsed note bullets from the LLM lesson-notes step.
    var noteBullets: [String] {
        guard let data = notes.data(using: .utf8) else { return [] }
        struct Bullet: Codable { var text: String }
        if let bullets = try? JSONDecoder().decode([Bullet].self, from: data) {
            return bullets.map { $0.text }
        }
        return notes.isEmpty ? [] : [notes]
    }

    var attribution: String {
        "© \(author) · \(publisher) · \(license)"
    }
}

// MARK: - Grade-tree helpers (grades.ts)

extension CourseIndexEntry {
    /// Map a course name to a MathTopic (grades.ts courseNameToTopic).
    var mathTopic: MathTopic {
        let n = name.lowercased()
        if n.contains("calculus") && !n.contains("pre-calculus") && !n.contains("precalculus") { return .calculus }
        if n.contains("pre-calculus") || n.contains("precalculus") { return .precalculus }
        if n.contains("geometry") { return .geometry }
        if n.contains("trigonometry") { return .trigonometry }
        if n.contains("statistics") || n.contains("data science") { return .statistics }
        if n.contains("discrete") { return .statistics }
        if n.contains("algebra 2") || n.contains("college algebra") { return .algebra2 }
        if n.contains("algebra 1") { return .algebra1 }
        if n.contains("pre-algebra") { return .preAlgebra }
        if n.contains("6th grade") || n.contains("7th grade") { return .preAlgebra }
        return .arithmetic
    }

    /// Stable hex → SwiftUI color (falls back to coral).
    var accentColor: MLColorAdapter {
        MLColorAdapter(hex: color)
    }
}

/// Tiny hex-color adapter so catalog data can carry its own accents
/// without leaking web CSS into SwiftUI views.
struct MLColorAdapter: Hashable {
    let red: Double
    let green: Double
    let blue: Double

    init(hex: String) {
        var value: UInt64 = 0xFF686B
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }
        if let parsed = UInt64(clean, radix: 16) { value = parsed }
        red = Double((value >> 16) & 0xFF) / 255.0
        green = Double((value >> 8) & 0xFF) / 255.0
        blue = Double(value & 0xFF) / 255.0
    }
}
