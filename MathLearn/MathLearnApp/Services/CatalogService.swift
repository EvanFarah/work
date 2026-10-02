//
//  CatalogService.swift
//  MathLearn
//
//  Loads the bundled course catalog (public/lessons/index.json +
//  courses/*.json) and the verified video catalog exported from the
//  import pipeline (Resources/Videos/videos.json). All data ships in
//  the app bundle — fully offline, with per-lesson attribution.
//

import Foundation

@MainActor
final class CatalogService: ObservableObject {

    @Published private(set) var courses: [CourseIndexEntry] = []
    @Published private(set) var videos: [VideoEntry] = []

    private var documents: [String: CourseDocument] = [:]   // slug → course doc

    // MARK: - Init / loading

    init() {
        loadIndex()
        loadVideos()
    }

    private func loadIndex() {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Catalog") ??
                Bundle.main.url(forResource: "index", withExtension: "json") else { return }
        if let data = try? Data(contentsOf: url),
           let index = try? JSONDecoder().decode(CourseIndex.self, from: data) {
            courses = index.courses
        }
    }

    private func loadVideos() {
        guard let url = Bundle.main.url(forResource: "videos", withExtension: "json", subdirectory: "Videos") ??
                Bundle.main.url(forResource: "videos", withExtension: "json") else { return }
        if let data = try? Data(contentsOf: url),
           let catalog = try? JSONDecoder().decode(VideoCatalog.self, from: data) {
            videos = catalog.videos
        }
    }

    // MARK: - Course documents (lazy per course, cached)

    func document(for slug: String) -> CourseDocument? {
        if let cached = documents[slug] { return cached }
        guard let url = Bundle.main.url(forResource: slug, withExtension: "json", subdirectory: "Catalog/courses") ??
                Bundle.main.url(forResource: slug, withExtension: "json") else { return nil }
        guard let data = try? Data(contentsOf: url),
              let doc = try? JSONDecoder().decode(CourseDocument.self, from: data) else { return nil }
        documents[slug] = doc
        return doc
    }

    func entry(for slug: String) -> CourseIndexEntry? {
        courses.first { $0.slug == slug }
    }

    /// Full ordered lesson list of a course (across units).
    func lessons(in slug: String) -> [LessonDocument] {
        document(for: slug)?.units.flatMap { $0.lessons } ?? []
    }

    // MARK: - Video matching (import pipeline ↔ course lessons)

    /// Best-effort match a course lesson to a verified import-pipeline
    /// video by title similarity (Mathispower4u catalog).
    func video(forLessonTitle title: String) -> VideoEntry? {
        let normalized = Self.normalize(title)
        guard normalized.count >= 8 else { return nil }
        var best: (entry: VideoEntry, score: Int)?
        for video in videos {
            let candidate = Self.normalize(video.title)
            let score = Self.commonPrefixLength(normalized, candidate)
            if score >= 14 && (best == nil || score > best!.score) {
                best = (video, score)
            }
        }
        return best?.entry
    }

    /// Search videos by free text (used by AI tutor / lesson deep links).
    func searchVideos(_ query: String, limit: Int = 6) -> [VideoEntry] {
        let q = Self.normalize(query)
        guard q.count >= 4 else { return [] }
        return videos
            .filter { Self.normalize($0.title).contains(q) || Self.normalize($0.topic).contains(q) }
            .prefix(limit)
            .map { $0 }
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .joined()
            .split(separator: " ")
            .joined(separator: " ")
    }

    private static func commonPrefixLength(_ a: String, _ b: String) -> Int {
        var i = 0
        let aArr = Array(a), bArr = Array(b)
        while i < aArr.count && i < bArr.count && aArr[i] == bArr[i] { i += 1 }
        return i
    }

    // MARK: - Search

    struct SearchResult: Identifiable {
        let course: CourseIndexEntry
        let unit: String
        let lesson: IndexLesson
        var id: String { course.slug + "|" + lesson.title }
    }

    func search(_ query: String) -> [SearchResult] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        var results: [SearchResult] = []
        for course in courses {
            if course.name.lowercased().contains(q) || course.gradeBand.lowercased().contains(q) {
                if let first = course.units.first?.lessons.first {
                    results.append(SearchResult(course: course, unit: course.units.first?.name ?? "", lesson: first))
                }
            }
            for unit in course.units {
                for lesson in unit.lessons {
                    if lesson.title.lowercased().contains(q) || lesson.description.lowercased().contains(q) {
                        results.append(SearchResult(course: course, unit: unit.name, lesson: lesson))
                    }
                }
            }
        }
        return Array(results.prefix(40))
    }
}
