//
//  PracticeHubView.swift
//  MathLearn
//
//  Port of PracticeHubView.tsx — Practice, Quizzes, Math Games, and
//  Course drills as tabs within a single learning/practice area.
//  Tab persistence + the dashboard's deep-link preset behavior.
//

import SwiftUI

struct PracticeHubView: View {
    @AppStorage("mathlearn.hub.practiceTab") private var tabRaw: String = PracticeTab.practice.rawValue
    private var tab: PracticeTab {
        get { PracticeTab(rawValue: tabRaw) ?? .practice }
        set { tabRaw = newValue.rawValue }
    }
    @State private var selected: PracticeTab = .practice
    @Namespace private var lens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            VStack(spacing: 0) {
                // Tab bar (sticker pill row)
                HStack(spacing: 4) {
                    hubTab(.practice, label: "Practice", icon: "bolt.fill")
                    hubTab(.quizzes, label: "Quizzes", icon: "trophy.fill")
                    hubTab(.games, label: "Games", icon: "gamecontroller.fill")
                    hubTab(.courses, label: "Courses", icon: "book.fill")
                }
                .padding(6)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(MLColor.ink, lineWidth: 2.5))
                .shadow(color: MLColor.ink.opacity(0.85), radius: 0, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Tab content
                switch selected {
                case .practice:
                    NavigationStack { PracticeView() }
                case .quizzes:
                    NavigationStack { QuizSetupView() }
                case .games:
                    NavigationStack { MathGamesView() }
                case .courses:
                    NavigationStack { CoursePracticeView() }
                }
            }
        }
        .onAppear { selected = tab }
        .onChange(of: selected) { _, newValue in tab = newValue }
        .onReceive(NotificationCenter.default.publisher(for: .mlPracticeTabRequest)) { note in
            if let requested = note.userInfo?["tab"] as? PracticeTab {
                selected = requested
                tab = requested
            }
        }
    }

    private func hubTab(_ key: PracticeTab, label: String, icon: String) -> some View {
        Button {
            withAnimation(MLMotion.adaptive(MLMotion.selection, reduceMotion: reduceMotion)) {
                selected = key
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .opacity(selected == key ? 1 : 0.55)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            // M2 — one coral lens glides between the 4 tabs via matched
            // geometry. Solid surface by law (never glass). Unselected tabs
            // show the bar's own white — visually identical to before.
            // Reduce Motion: plain color swap (animation above is nil).
            .background {
                if selected == key {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MLColor.coral)
                        .matchedGeometryEffect(id: "hub-selection-lens", in: lens)
                }
            }
            .foregroundStyle(selected == key ? Color.white : MLColor.ink.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Courses tab of the hub (CoursePracticeView.tsx port)

struct CoursePracticeView: View {
    @EnvironmentObject private var catalog: CatalogService
    @EnvironmentObject private var store: StudyStore

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(
                        badgeText: "📚 Courses",
                        badgeTone: .blue,
                        title: "Course Drills",
                        subtitle: "Browse every course, unit, and lesson — drill any lesson with the adaptive engine."
                    )
                    ForEach(catalog.courses) { course in
                        NavigationLink {
                            CourseDetailView(course: course, drillMode: true)
                        } label: {
                            HStack(spacing: 12) {
                                Text(course.icon)
                                    .font(.system(size: 18))
                                    .frame(width: 42, height: 42)
                                    .background(Color(red: course.accentColor.red, green: course.accentColor.green, blue: course.accentColor.blue))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(course.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(MLColor.ink)
                                        .lineLimit(1)
                                    Text("\(course.lessonCount) lessons · \(course.gradeBand)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .stickerCard(radius: 18, lift: 4)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Courses")
        .navigationBarTitleDisplayMode(.inline)
    }
}
