//
//  ModulesView.swift
//  MathLearn
//
//  The Modules tab: searchable course grid (19 courses) → course
//  detail with unit accordions and lesson rows → the lesson player.
//

import SwiftUI

struct ModulesView: View {
    @EnvironmentObject private var catalog: CatalogService
    @State private var query = ""

    private var filtered: [CourseIndexEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return catalog.courses }
        return catalog.courses.filter {
            $0.name.lowercased().contains(q)
                || $0.gradeBand.lowercased().contains(q)
                || $0.description.lowercased().contains(q)
                || $0.units.contains { unit in
                    unit.lessons.contains { $0.title.lowercased().contains(q) }
                }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MLColor.cream.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(
                            badgeText: "📖 Modules",
                            badgeTone: .blue,
                            title: "Browse Courses",
                            subtitle: "19 courses from 1st grade through college — every lesson ships with full attribution."
                        )

                        // Search field
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search courses or lessons…", text: $query)
                                .font(.subheadline.weight(.medium))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            if !query.isEmpty {
                                Button {
                                    query = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))

                        if filtered.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.tertiary)
                                Text("No matches for “\(query)”")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                                ForEach(filtered) { course in
                                    NavigationLink {
                                        CourseDetailView(course: course)
                                    } label: {
                                        courseCard(course)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Lessons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { MoreToolbarButton() } }
        }
    }

    private func courseCard(_ course: CourseIndexEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(course.icon)
                    .font(.system(size: 24))
                    .frame(width: 50, height: 50)
                    .background(Color(red: course.accentColor.red, green: course.accentColor.green, blue: course.accentColor.blue))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                Spacer()
                StickerBadge(text: course.gradeBand, tone: .white)
            }
            Text(course.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MLColor.ink)
                .lineLimit(2)
            Text(course.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack {
                Label("\(course.lessonCount) lessons", systemImage: "play.rectangle")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Label("\(course.units.count) units", systemImage: "square.stack.3d.up")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .stickerCard(radius: 18, lift: 4)
    }
}

// MARK: - Course detail (units + lessons)

struct CourseDetailView: View {
    @EnvironmentObject private var catalog: CatalogService
    @EnvironmentObject private var store: StudyStore

    let course: CourseIndexEntry
    var drillMode: Bool = false

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Course header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text(course.icon)
                                .font(.system(size: 26))
                                .frame(width: 56, height: 56)
                                .background(Color(red: course.accentColor.red, green: course.accentColor.green, blue: course.accentColor.blue))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .stickerCard(radius: 16, lift: 4)
                            Spacer()
                            StickerBadge(text: course.gradeBand, tone: .white)
                        }
                        Text(course.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(MLColor.ink)
                        Text(course.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        StickerProgress(
                            value: completionPct,
                            tone: .mint
                        )
                        Text("\(completedCount) of \(course.lessonCount) lessons completed")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .stickerCard()

                    // Units
                    ForEach(Array((catalog.document(for: course.slug)?.units ?? []).enumerated()), id: \.element.name) { unitIndex, unit in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("Unit \(unitIndex + 1)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.8)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(MLColor.yellow)
                                    .clipShape(Capsule())
                                Text(unit.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(MLColor.ink)
                                Spacer()
                            }
                            .padding(.horizontal, 2)

                            VStack(spacing: 8) {
                                ForEach(unit.lessons) { lesson in
                                    NavigationLink {
                                        LessonPlayerView(course: course, unitName: unit.name, lessonTitle: lesson.title)
                                    } label: {
                                        HStack(spacing: 12) {
                                            lessonBadge(lesson.title)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(lesson.title)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(MLColor.ink)
                                                    .multilineTextAlignment(.leading)
                                                Text(lesson.description)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.leading)
                                            }
                                            Spacer(minLength: 4)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(12)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MLColor.ink.opacity(0.12), lineWidth: 1.5))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lessonBadge(_ title: String) -> some View {
        let done = store.isLessonCompleted(courseSlug: course.slug, lessonTitle: title)
        return Image(systemName: done ? "checkmark.circle.fill" : "play.circle")
            .font(.system(size: 19))
            .foregroundStyle(done ? MLColor.mintStrong : MLColor.coral)
    }

    private var completedCount: Int {
        course.units.flatMap { $0.lessons }.filter { store.isLessonCompleted(courseSlug: course.slug, lessonTitle: $0.title) }.count
    }

    private var completionPct: Double {
        course.lessonCount > 0 ? Double(completedCount) / Double(course.lessonCount) * 100 : 0
    }
}
