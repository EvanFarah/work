//
//  LessonPlayerView.swift
//  MathLearn
//
//  The lesson player — LearnStage.tsx / LessonSlidesViewer port:
//   • video step: verified Mathispower4u YouTube embed (when matched)
//   • document: content, formula, vocabulary, steps, examples, tip
//   • lesson quiz: built-in Q/A self-check
//   • attribution footer (license + author + publisher — required)
//   • mark complete (+25 XP) and next-lesson navigation
//

import SwiftUI
import WebKit

struct LessonPlayerView: View {
    @EnvironmentObject private var catalog: CatalogService
    @EnvironmentObject private var store: StudyStore

    let course: CourseIndexEntry
    let unitName: String
    let lessonTitle: String

    @State private var showQuiz = false
    @State private var justCompleted = false

    private var lesson: LessonDocument? {
        catalog.lessons(in: course.slug).first { $0.title == lessonTitle }
    }

    private var video: VideoEntry? {
        catalog.video(forLessonTitle: lessonTitle)
    }

    private var nextLesson: LessonDocument? {
        let all = catalog.lessons(in: course.slug)
        guard let idx = all.firstIndex(where: { $0.title == lessonTitle }) else { return nil }
        let next = idx + 1
        return next < all.count ? all[next] : nil
    }

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let lesson { document(lesson) }
                    if let lesson { lessonQuiz(lesson) }
                    attribution
                    actions
                }
                .padding(16)
                .padding(.bottom, 40)
            }

            if justCompleted {
                completionOverlay
            }
        }
        .navigationTitle(unitName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let topic = course.mathTopicForCourse {
                store.setLastStudied(
                    courseSlug: course.slug,
                    courseLabel: course.name,
                    lessonTitle: lessonTitle,
                    topic: topic,
                    stage: "learn"
                )
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                StickerBadge(text: course.name, tone: .white)
                Spacer()
                if store.isLessonCompleted(courseSlug: course.slug, lessonTitle: lessonTitle) {
                    StickerBadge(text: "✓ Completed", tone: MLColor.mint, foreground: MLColor.ink)
                }
            }
            Text(lessonTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(MLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let lesson {
                Text(lesson.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Video step (YouTube embed)

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StickerBadge(text: "🎬 Video lesson", tone: MLColor.coral, foreground: .white)
                Spacer()
            }
            YouTubeEmbedView(youtubeId: video!.youtubeId)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MLColor.ink, lineWidth: 2.5))
        }
    }

    @ViewBuilder
    private func document(_ lesson: LessonDocument) -> some View {
        if video != nil {
            videoSection
        }

        // Formula / key ideas
        if let formula = lesson.formula, !formula.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                StickerBadge(text: "🧠 Key formulas", tone: MLColor.yellow, foreground: MLColor.ink)
                Text(formula)
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .foregroundStyle(MLColor.ink)
                    .lineSpacing(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
        }

        // Content (HTML → attributed text)
        if let content = lesson.content, !content.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                StickerBadge(text: "📘 The lesson", tone: MLColor.blue, foreground: MLColor.ink)
                HTMLText(html: content)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
        }

        // Steps
        if let steps = lesson.steps, !steps.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                StickerBadge(text: "🪜 Steps", tone: MLColor.mint, foreground: MLColor.ink)
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(MLColor.cream)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(MLColor.ink.opacity(0.2), lineWidth: 1.5))
                        Text(step)
                            .font(.footnote)
                            .foregroundStyle(MLColor.ink)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
        }

        // Examples
        if let examples = lesson.examples, !examples.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                StickerBadge(text: "✏️ Worked examples", tone: MLColor.purple, foreground: .white)
                ForEach(Array(examples.prefix(4).enumerated()), id: \.offset) { _, ex in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ex.problem)
                            .font(.footnote.weight(.heavy))
                            .foregroundStyle(MLColor.ink)
                        Text(ex.answer)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(MLColor.mintStrong)
                        if let work = ex.work, !work.isEmpty {
                            Text(work)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MLColor.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
        }

        // Vocabulary
        if let vocab = lesson.vocabulary, !vocab.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                StickerBadge(text: "🔤 Vocabulary", tone: .white)
                FlowLayoutBadges(words: vocab)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
        }

        // Tip
        if let tip = lesson.tip, !tip.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                Text("💡")
                    .font(.system(size: 20))
                Text(tip)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MLColor.ink)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MLColor.yellow.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MLColor.ink.opacity(0.25), lineWidth: 1.5))
        }
    }

    // MARK: Lesson quiz

    private func lessonQuiz(_ lesson: LessonDocument) -> some View {
        Group {
            if let quiz = lesson.quiz, !quiz.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        StickerBadge(text: "🎯 Check yourself", tone: MLColor.coral, foreground: .white)
                        Spacer()
                        Button(showQuiz ? "Hide" : "Show") {
                            withAnimation { showQuiz.toggle() }
                        }
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(MLColor.coral)
                    }
                    if showQuiz {
                        ForEach(Array(quiz.enumerated()), id: \.offset) { i, item in
                            LessonQuizRow(index: i + 1, item: item)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
            }
        }
    }

    // MARK: Attribution (license requirement)

    private var attribution: some View {
        Group {
            if let video {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Video attribution")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(video.attribution)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let url = URL(string: video.originalVideoUrl) {
                        Link("View original on YouTube", destination: url)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(MLColor.coral)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(MLColor.cream)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MLColor.ink.opacity(0.12), lineWidth: 1))
            }
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                complete()
            } label: {
                Label(
                    store.isLessonCompleted(courseSlug: course.slug, lessonTitle: lessonTitle)
                        ? "Completed — practice again"
                        : "Mark lesson complete",
                    systemImage: store.isLessonCompleted(courseSlug: course.slug, lessonTitle: lessonTitle) ? "checkmark.seal.fill" : "checkmark"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(store.isLessonCompleted(courseSlug: course.slug, lessonTitle: lessonTitle) ? .stickerWhite : .stickerCoral)

            if let next = nextLesson {
                NavigationLink {
                    LessonPlayerView(course: course, unitName: unitName, lessonTitle: next.title)
                } label: {
                    Label("Next: \(next.title)", systemImage: "arrow.right")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.stickerWhite)
            }
        }
    }

    private var completionOverlay: some View {
        ZStack {
            MLColor.cream.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                    .frame(width: 60, height: 60)
                    .background(MLColor.mint)
                    .clipShape(Circle())
                    .stickerCard(radius: 30, lift: 0)
                Text("Lesson complete!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MLColor.ink)
                Text("+25 XP banked")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(MLColor.mintStrong)
                Button {
                    justCompleted = false
                } label: {
                    Text("Keep going")
                        .frame(maxWidth: 220)
                }
                .buttonStyle(.stickerCoral)
            }
            .padding(26)
        }
        .overlay { ConfettiView(trigger: 1) }
    }

    private func complete() {
        guard let topic = course.mathTopicForCourse else { return }
        store.markLessonCompleted(courseSlug: course.slug, lessonTitle: lessonTitle, topic: topic)
        justCompleted = true
    }
}

extension CourseIndexEntry {
    var mathTopicForCourse: MathTopic? { mathTopic }
}

// MARK: - Lesson quiz self-check row

private struct LessonQuizRow: View {
    let index: Int
    let item: LessonQuizItem
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(index). \(item.question)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MLColor.ink)
            if revealed {
                Text(item.answer)
                    .font(.footnote.weight(.heavy))
                    .foregroundStyle(MLColor.mintStrong)
            } else {
                Button("Reveal answer") { withAnimation { revealed = true } }
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(MLColor.coral)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MLColor.cream)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Vocabulary wrap layout

struct FlowLayoutBadges: View {
    let words: [String]

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(words, id: \.self) { word in
                    Text(word)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(MLColor.cream)
                        .foregroundStyle(MLColor.ink)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(MLColor.ink.opacity(0.2), lineWidth: 1.2))
                        .alignmentGuide(.leading) { dim in
                            if abs(width - dim.width) > geo.size.width {
                                width = 0
                                height -= dim.height + 6
                            }
                            let result = width
                            if word == words.last {
                                width = 0
                            } else {
                                width -= dim.width + 6
                            }
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if word == words.last { height = 0 }
                            return result
                        }
                }
            }
        }
        .frame(height: CGFloat((words.count / 3 + 1)) * 32)
    }
}

// MARK: - HTML → text

struct HTMLText: View {
    let html: String

    var body: some View {
        Group {
            if let attributed = try? AttributedString(
                html,
                options: .init([
                    .interpretedSyntax: .inlineOnlyPreservingWhitespace
                ])
            ) {
                Text(attributed)
                    .font(.footnote)
                    .foregroundStyle(MLColor.ink)
                    .lineSpacing(3)
            } else {
                Text(html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                    .font(.footnote)
                    .foregroundStyle(MLColor.ink)
            }
        }
    }
}

// MARK: - YouTube embed (WKWebView)

struct YouTubeEmbedView: UIViewRepresentable {
    let youtubeId: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        let html = """
        <!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>body{margin:0;background:#24163A}iframe{width:100%;height:100%;border:0}</style></head>
        <body><iframe src="https://www.youtube-nocookie.com/embed/\(youtubeId)?playsinline=1&rel=0" allow="accelerometer; autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe></body></html>
        """
        web.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
