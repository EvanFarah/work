//
//  StudyModels.swift
//  MathLearn
//
//  Domain models for the practice engine, mirroring src/lib/math/topics.ts
//  and the web study-store (PlayerStats, TrackedMistake, notes, flashcards).
//

import Foundation

// MARK: - Topics (topics.ts)

enum MathTopic: String, Codable, CaseIterable, Identifiable {
    case arithmetic, fractions, decimals, percentages, ratios
    case preAlgebra = "pre-algebra"
    case algebra1 = "algebra-1"
    case algebra2 = "algebra-2"
    case geometry, trigonometry, precalculus, calculus, statistics

    var id: String { rawValue }

    var label: String {
        switch self {
        case .arithmetic: return "Arithmetic"
        case .fractions: return "Fractions"
        case .decimals: return "Decimals"
        case .percentages: return "Percentages"
        case .ratios: return "Ratios"
        case .preAlgebra: return "Pre-Algebra"
        case .algebra1: return "Algebra 1"
        case .algebra2: return "Algebra 2"
        case .geometry: return "Geometry"
        case .trigonometry: return "Trigonometry"
        case .precalculus: return "Precalculus"
        case .calculus: return "Calculus"
        case .statistics: return "Statistics"
        }
    }
}

enum MathDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard, expert

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    /// Seconds per question (questions.ts timeForDifficulty).
    var timeLimit: Int {
        switch self {
        case .easy: return 30
        case .medium: return 25
        case .hard: return 20
        case .expert: return 15
        }
    }

    /// XP multiplier per correct answer.
    var xpMultiplier: Int {
        switch self {
        case .easy: return 10
        case .medium: return 15
        case .hard: return 20
        case .expert: return 30
        }
    }

    var next: MathDifficulty {
        switch self {
        case .easy: return .medium
        case .medium: return .hard
        case .hard: return .expert
        case .expert: return .expert
        }
    }

    var previous: MathDifficulty {
        switch self {
        case .easy: return .easy
        case .medium: return .easy
        case .hard: return .medium
        case .expert: return .hard
        }
    }
}

// MARK: - Question (topics.ts MathQuestion)

struct MathQuestion: Identifiable, Equatable {
    let id: String
    let topic: MathTopic
    let subtopic: String
    let difficulty: MathDifficulty
    let question: String
    let answer: String
    let options: [String]
    let timeLimit: Int
    let hint: String
    let explanation: String
}

// MARK: - Topic tree (topics.ts TOPIC_TREE)

struct SubtopicInfo: Identifiable, Codable, Hashable {
    let key: String
    let label: String
    let mathTopics: [MathTopic]

    var id: String { key }
}

struct TopicInfo: Identifiable, Codable, Hashable {
    let key: String
    let label: String
    let blurb: String
    let grades: [String]
    let icon: String
    let color: String          // mint | blue | yellow | coral | purple
    let subtopics: [SubtopicInfo]

    var id: String { key }
}

// MARK: - Study selection (study-store StudySelection)

struct StudySelection: Equatable {
    var subjectKey: String
    var subjectLabel: String
    var subtopicKey: String
    var subtopicLabel: String
    var topic: MathTopic
    var difficulty: MathDifficulty = .medium
}

// MARK: - Player stats (study-store PlayerStats)

struct PlayerStats: Codable, Equatable {
    var xp: Int = 0
    var streakDays: Int = 0
    var totalAnswered: Int = 0
    var totalCorrect: Int = 0
    /// Mastery % per MathTopic raw value.
    var mastery: [String: Double] = [:]
    /// Completed lesson slugs (course-lesson pairs) and subtopic keys.
    var lessonsCompleted: [String] = []
    /// Last position for "Jump Back In" (dashboard).
    var lastStudied: LastStudied?
    /// Per-topic practice activity — powers the Premium "Likely to Forget"
    /// predictions (days since last practice × accuracy history → decay %).
    /// Optional so older persisted stats decode without migration.
    var topicActivity: [String: TopicActivity]?

    struct TopicActivity: Codable, Equatable {
        var lastPracticed: Date
        var correct: Int
        var total: Int
    }

    struct LastStudied: Codable, Equatable {
        var courseSlug: String
        var courseLabel: String
        var lessonSlug: String
        var lessonTitle: String
        var topic: MathTopic
        var stage: String   // learn | practice | quiz | results
        var at: Date
    }

    var level: Int { 1 + xp / 500 }

    var accuracy: Int {
        totalAnswered > 0 ? Int(round(Double(totalCorrect) / Double(totalAnswered) * 100)) : 0
    }

    var overallMastery: Int {
        let values = mastery.values.map { $0 }
        guard !values.isEmpty else { return 0 }
        return Int(round(values.reduce(0, +) / Double(values.count)))
    }

    func mastery(for topic: MathTopic) -> Double { mastery[topic.rawValue] ?? 0 }
}

// MARK: - Tracked mistake (study-store TrackedMistake)

struct TrackedMistake: Identifiable, Codable, Equatable {
    var id: String
    var questionText: String
    var correctAnswer: String
    var userAnswer: String
    var topic: MathTopic
    var subject: String
    var difficulty: MathDifficulty
    var timestamp: Date
    var analysis: MistakeAnalysis?

    struct MistakeAnalysis: Codable, Equatable {
        var whyWrong: String
        var misconception: String
        var fixTip: String
    }
}

// MARK: - Note (NotesView)

struct Note: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var body: String
    var tag: String
    var updatedAt: Date
}

// MARK: - Flashcard (FlashcardsView)

struct Flashcard: Identifiable, Codable, Equatable {
    var id: String
    var front: String
    var back: String
}

// MARK: - Quiz attempt (history / analytics)

struct QuizAttempt: Identifiable, Codable, Equatable {
    var id: String
    var label: String
    var subject: String
    var topic: MathTopic
    var difficulty: MathDifficulty
    var score: Int
    var total: Int
    var xpEarned: Int
    var durationSec: Int
    var at: Date
}

// MARK: - Daily XP (analytics bar chart)

struct DailyXP: Codable, Equatable {
    var day: Date        // normalized to midnight
    var xp: Int
    var answers: Int
    var correct: Int
}

// MARK: - Achievement defs (AchievementsView.tsx)

struct AchievementDef: Identifiable {
    let id: String
    let label: String
    let description: String
    let emoji: String
    let tone: Tone

    func isUnlocked(_ s: PlayerStats) -> Bool { progress(s).current >= progress(s).target }

    func progress(_ s: PlayerStats) -> (current: Int, target: Int) {
        switch id {
        case "first-step":   return (min(s.totalAnswered, 1), 1)
        case "xp-100":       return (min(s.xp, 100), 100)
        case "streak-3":     return (min(s.streakDays, 3), 3)
        case "lesson-3":     return (min(s.lessonsCompleted.count, 3), 3)
        case "answered-50":  return (min(s.totalAnswered, 50), 50)
        case "master-1":     return (min(s.mastery.values.filter { $0 >= 80 }.count, 1), 1)
        case "level-5":      return (min(s.level, 5), 5)
        case "streak-7":     return (min(s.streakDays, 7), 7)
        case "xp-500":       return (min(s.xp, 500), 500)
        case "answered-100": return (min(s.totalAnswered, 100), 100)
        case "lesson-10":    return (min(s.lessonsCompleted.count, 10), 10)
        case "level-10":     return (min(s.level, 10), 10)
        default:             return (0, 1)
        }
    }

    static let all: [AchievementDef] = [
        AchievementDef(id: "first-step", label: "First Step", description: "Answer your first question", emoji: "👟", tone: .mint),
        AchievementDef(id: "xp-100", label: "Century", description: "Earn 100 XP", emoji: "⭐", tone: .yellow),
        AchievementDef(id: "streak-3", label: "On Fire", description: "Reach a 3-day streak", emoji: "🔥", tone: .coral),
        AchievementDef(id: "lesson-3", label: "Bookworm", description: "Complete 3 lessons", emoji: "📚", tone: .blue),
        AchievementDef(id: "answered-50", label: "Half-Century", description: "Answer 50 questions", emoji: "🎯", tone: .purple),
        AchievementDef(id: "master-1", label: "Master", description: "Master a topic (80%+)", emoji: "🏆", tone: .yellow),
        AchievementDef(id: "level-5", label: "Rising Star", description: "Reach level 5", emoji: "🚀", tone: .coral),
        AchievementDef(id: "streak-7", label: "Week Warrior", description: "Reach a 7-day streak", emoji: "🌟", tone: .purple),
        AchievementDef(id: "xp-500", label: "XP Hunter", description: "Earn 500 XP", emoji: "💎", tone: .blue),
        AchievementDef(id: "answered-100", label: "Centurion", description: "Answer 100 questions", emoji: "⚔️", tone: .mint),
        AchievementDef(id: "lesson-10", label: "Scholar", description: "Complete 10 lessons", emoji: "🎓", tone: .coral),
        AchievementDef(id: "level-10", label: "Mathematician", description: "Reach level 10", emoji: "👑", tone: .yellow),
    ]
}
