//
//  StudyStore.swift
//  MathLearn
//
//  The player data layer — a port of the web study-store (zustand).
//  Holds PlayerStats, mistakes, notes, flashcards, quiz history and
//  daily-XP analytics; persists everything to Application Support as
//  JSON so the app works fully offline.
//

import Foundation
import Combine

@MainActor
final class StudyStore: ObservableObject {

    // MARK: - Published state

    @Published private(set) var stats = PlayerStats()
    @Published private(set) var mistakes: [TrackedMistake] = []
    @Published var notes: [Note] = []
    @Published var flashcards: [Flashcard] = []
    @Published private(set) var attempts: [QuizAttempt] = []
    @Published private(set) var dailyXP: [DailyXP] = []

    // MARK: - Persistence

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MathLearn", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("study-state.json")
    }()

    private struct Snapshot: Codable {
        var stats: PlayerStats
        var mistakes: [TrackedMistake]
        var notes: [Note]
        var flashcards: [Flashcard]
        var attempts: [QuizAttempt]
        var dailyXP: [DailyXP]
    }

    init() {
        load()
        rollStreakIfNeeded()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            stats = snapshot.stats
            mistakes = snapshot.mistakes
            notes = snapshot.notes
            flashcards = snapshot.flashcards
            attempts = snapshot.attempts
            dailyXP = snapshot.dailyXP
        }
    }

    private func persist() {
        let snapshot = Snapshot(
            stats: stats, mistakes: mistakes, notes: notes,
            flashcards: flashcards, attempts: attempts, dailyXP: dailyXP
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - Streak (any study activity keeps it alive)

    private var lastActiveDay: Date? {
        didSet { persist() }
    }

    private func rollStreakIfNeeded() {
        let today = Self.midnight(Date())
        guard let last = lastActiveDay else {
            lastActiveDay = today
            stats.streakDays = max(1, stats.streakDays == 0 ? 1 : stats.streakDays)
            return
        }
        let days = Calendar.current.dateComponents([.day], from: last, to: today).day ?? 0
        if days == 0 { return }
        if days == 1 {
            stats.streakDays += 1
        } else if days > 1 {
            stats.streakDays = 1
        }
        lastActiveDay = today
    }

    private static func midnight(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    // MARK: - Answer recording (quiz + practice + games)

    func recordAnswer(topic: MathTopic, difficulty: MathDifficulty, correct: Bool) {
        stats.totalAnswered += 1
        if correct {
            stats.totalCorrect += 1
            let xp = difficulty.xpMultiplier
            awardXP(xp)
            // Mastery climbs toward 100 with diminishing steps.
            let current = stats.mastery(for: topic)
            let next = min(100, current + max(2, (100 - current) * 0.15))
            stats.mastery[topic.rawValue] = next
        } else {
            // Mastery decays but never below 0.
            let current = stats.mastery(for: topic)
            stats.mastery[topic.rawValue] = max(0, current - 6)
        }
        // Rolling activity per topic — drives Likely to Forget (Premium).
        var activity = stats.topicActivity ?? [:]
        var entry = activity[topic.rawValue] ?? PlayerStats.TopicActivity(lastPracticed: Date(), correct: 0, total: 0)
        entry.lastPracticed = Date()
        entry.total += 1
        if correct { entry.correct += 1 }
        activity[topic.rawValue] = entry
        stats.topicActivity = activity
        bumpDaily(correct: correct, xp: correct ? difficulty.xpMultiplier : 0)
        persist()
    }

    func trackMistake(question: MathQuestion, userAnswer: String) {
        let mistake = TrackedMistake(
            id: UUID().uuidString,
            questionText: question.question,
            correctAnswer: question.answer,
            userAnswer: userAnswer,
            topic: question.topic,
            subject: question.topic.label,
            difficulty: question.difficulty,
            timestamp: Date(),
            analysis: nil
        )
        mistakes.insert(mistake, at: 0)
        if mistakes.count > 200 { mistakes.removeLast(mistakes.count - 200) }
        persist()
    }

    func setAnalysis(_ analysis: TrackedMistake.MistakeAnalysis, for id: String) {
        guard let idx = mistakes.firstIndex(where: { $0.id == id }) else { return }
        mistakes[idx].analysis = analysis
        persist()
    }

    // MARK: - XP / levels

    func awardXP(_ amount: Int) {
        stats.xp += amount
        bumpDaily(correct: nil, xp: amount)
    }

    private func bumpDaily(correct: Bool?, xp: Int) {
        let today = Self.midnight(Date())
        if let idx = dailyXP.firstIndex(where: { Calendar.current.isDate($0.day, inSameDayAs: today) }) {
            dailyXP[idx].xp += xp
            if let correct { dailyXP[idx].answers += 1; if correct { dailyXP[idx].correct += 1 } }
        } else {
            dailyXP.append(DailyXP(day: today, xp: xp, answers: correct != nil ? 1 : 0, correct: correct == true ? 1 : 0))
            if dailyXP.count > 90 { dailyXP.removeFirst(dailyXP.count - 90) }
        }
    }

    // MARK: - Lessons

    func markLessonCompleted(courseSlug: String, lessonTitle: String, topic: MathTopic) {
        let key = "\(courseSlug)|\(LessonDocument.slugify(lessonTitle))"
        if !stats.lessonsCompleted.contains(key) {
            stats.lessonsCompleted.append(key)
            awardXP(25)
        }
        stats.lastStudied = PlayerStats.LastStudied(
            courseSlug: courseSlug,
            courseLabel: courseSlug,
            lessonSlug: LessonDocument.slugify(lessonTitle),
            lessonTitle: lessonTitle,
            topic: topic,
            stage: "learn",
            at: Date()
        )
        persist()
    }

    func setLastStudied(courseSlug: String, courseLabel: String, lessonTitle: String, topic: MathTopic, stage: String) {
        stats.lastStudied = PlayerStats.LastStudied(
            courseSlug: courseSlug,
            courseLabel: courseLabel,
            lessonSlug: LessonDocument.slugify(lessonTitle),
            lessonTitle: lessonTitle,
            topic: topic,
            stage: stage,
            at: Date()
        )
        persist()
    }

    func isLessonCompleted(courseSlug: String, lessonTitle: String) -> Bool {
        stats.lessonsCompleted.contains("\(courseSlug)|\(LessonDocument.slugify(lessonTitle))")
    }

    // MARK: - Attempts

    func recordAttempt(_ attempt: QuizAttempt) {
        attempts.insert(attempt, at: 0)
        if attempts.count > 100 { attempts.removeLast(attempts.count - 100) }
        persist()
    }

    // MARK: - Notes / flashcards

    func addNote(title: String, body: String, tag: String) {
        let note = Note(
            id: "note_\(Int(Date().timeIntervalSince1970 * 1000))",
            title: title.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : title.trimmingCharacters(in: .whitespaces),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            tag: tag.trimmingCharacters(in: .whitespaces),
            updatedAt: Date()
        )
        notes.insert(note, at: 0)
        persist()
    }

    func deleteNote(_ id: String) {
        notes.removeAll { $0.id == id }
        persist()
    }

    func addFlashcard(front: String, back: String) {
        let card = Flashcard(
            id: "card_\(Int(Date().timeIntervalSince1970 * 1000))",
            front: front.trimmingCharacters(in: .whitespaces),
            back: back.trimmingCharacters(in: .whitespaces)
        )
        flashcards.insert(card, at: 0)
        persist()
    }

    func deleteFlashcard(_ id: String) {
        flashcards.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Reset

    func resetAll() {
        stats = PlayerStats()
        mistakes = []
        notes = []
        flashcards = []
        attempts = []
        dailyXP = []
        lastActiveDay = Self.midnight(Date())
        stats.streakDays = 1
        persist()
    }

    // MARK: - Analytics helpers

    /// Last 7 days of XP (oldest → newest) for the weekly bar chart.
    var weeklyXP: [DailyXP] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            if let hit = dailyXP.first(where: { cal.isDate($0.day, inSameDayAs: day) }) {
                return hit
            }
            return DailyXP(day: day, xp: 0, answers: 0, correct: 0)
        }
    }

    /// Weak topics: lowest mastery among topics with at least some data.
    var weakestTopics: [(topic: MathTopic, mastery: Double)] {
        MathTopic.allCases
            .map { ($0, stats.mastery(for: $0)) }
            .sorted { $0.1 < $1.1 }
    }
}
