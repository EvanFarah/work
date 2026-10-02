//
//  FlashcardsView.swift + NotesView.swift
//  MathLearn
//
//  Ports of FlashcardsView.tsx and NotesView.tsx — the local-first
//  study tools: tap-to-flip flashcard deck review, and a notepad
//  with topic tags. All data persists through StudyStore.
//

import SwiftUI

// MARK: - Flashcards

struct FlashcardsView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var reviewing = false
    @State private var reviewIndex = 0
    @State private var flipped = false
    @State private var front = ""
    @State private var back = ""

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if reviewing && !store.flashcards.isEmpty {
                        reviewMode
                    } else {
                        deckManager
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: Deck manager

    private var deckManager: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    StickerBadge(text: "🃏 Flashcards", tone: MLColor.purple, foreground: .white)
                    Text("Create cards and review them with a tap-to-flip deck.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !store.flashcards.isEmpty {
                    Button {
                        reviewIndex = 0
                        flipped = false
                        withAnimation { reviewing = true }
                    } label: {
                        Label("Review (\(store.flashcards.count))", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.stickerCoral)
                }
            }

            // New card form
            VStack(alignment: .leading, spacing: 10) {
                StickerBadge(text: "New card", tone: MLColor.mint, foreground: MLColor.ink)
                field("Front (question)", text: $front)
                field("Back (answer)", text: $back)
                Button {
                    guard !front.trimmingCharacters(in: .whitespaces).isEmpty,
                          !back.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    store.addFlashcard(front: front, back: back)
                    front = ""
                    back = ""
                } label: {
                    Label("Add card", systemImage: "plus")
                }
                .buttonStyle(.stickerYellow)
            }
            .padding(16)
            .stickerCard(radius: 18, lift: 4)

            // Card list
            if store.flashcards.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No cards yet")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MLColor.ink)
                    Text("Add your first flashcard above to build a deck.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(26)
                .stickerCard(radius: 18, lift: 4)
            } else {
                ForEach(store.flashcards) { card in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("FRONT")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            Text(card.front)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(MLColor.ink)
                            Text("BACK")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            Text(card.back)
                                .font(.footnote)
                                .foregroundStyle(MLColor.ink.opacity(0.85))
                        }
                        Spacer(minLength: 6)
                        Button {
                            store.deleteFlashcard(card.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(MLColor.coral)
                                .frame(width: 32, height: 32)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
                        }
                        .accessibilityLabel("Delete card")
                    }
                    .padding(14)
                    .stickerCard(radius: 16, lift: 3)
                }
            }
        }
    }

    // MARK: Review mode

    private var reviewMode: some View {
        let card = store.flashcards[reviewIndex]
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    StickerBadge(text: "🃏 Reviewing", tone: MLColor.purple, foreground: .white)
                    Text("Card \(reviewIndex + 1) of \(store.flashcards.count)")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(MLColor.ink)
                }
                Spacer()
                Button("Exit review") {
                    withAnimation { reviewing = false }
                }
                .buttonStyle(.stickerWhite)
            }

            // Flip card — motion: spring flip; Reduce Motion: gentle
            // crossfade with no spring wobble (vestibular-safe branch).
            Button {
                withAnimation(reduceMotion ? MLMotion.crossfade : MLMotion.flip) {
                    flipped.toggle()
                }
            } label: {
                VStack(spacing: 12) {
                    StickerBadge(text: flipped ? "Answer" : "Question", tone: flipped ? .white : MLColor.yellow)
                    Text(flipped ? card.back : card.front)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(MLColor.ink)
                        .multilineTextAlignment(.center)
                    Text("Tap to \(flipped ? "see question" : "reveal answer")")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .padding(22)
                .background(flipped ? MLColor.mint : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(MLColor.ink, lineWidth: 3))
                .shadow(color: MLColor.ink.opacity(0.9), radius: 0, x: 0, y: 6)
            }

            // Nav
            HStack {
                Button {
                    flipped = false
                    reviewIndex = (reviewIndex - 1 + store.flashcards.count) % store.flashcards.count
                } label: {
                    Label("Prev", systemImage: "chevron.left")
                }
                .buttonStyle(.stickerWhite)
                Spacer()
                Text("\(reviewIndex + 1) / \(store.flashcards.count)")
                    .font(.footnote.weight(.heavy))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    flipped = false
                    reviewIndex = (reviewIndex + 1) % store.flashcards.count
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .buttonStyle(.stickerCoral)
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .lineLimit(1...3)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(MLColor.cream)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
    }
}

// MARK: - Notes

struct NotesView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var bodyText = ""
    @State private var tag = ""

    var body: some View {
        ZStack {
            MLColor.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        StickerBadge(text: "📝 Notes", tone: MLColor.blue, foreground: MLColor.ink)
                        Text("Your notes")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(MLColor.ink)
                        Text("Jot down formulas, tricks, and reminders. Saved on this device.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    // New note form
                    VStack(alignment: .leading, spacing: 10) {
                        StickerBadge(text: "New note", tone: MLColor.mint, foreground: MLColor.ink)
                        TextField("Title (e.g. Quadratic formula)", text: $title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(MLColor.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
                        TextField("Write your note here…", text: $bodyText, axis: .vertical)
                            .lineLimit(4...8)
                            .font(.footnote)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(MLColor.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
                        HStack(spacing: 10) {
                            Image(systemName: "tag")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                            TextField("Topic tag (optional)", text: $tag)
                                .font(.footnote.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(MLColor.cream)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
                            Spacer()
                            Button {
                                store.addNote(title: title, body: bodyText, tag: tag)
                                title = ""
                                bodyText = ""
                                tag = ""
                            } label: {
                                Label("Add note", systemImage: "plus")
                            }
                            .buttonStyle(.stickerCoral)
                        }
                    }
                    .padding(16)
                    .stickerCard(radius: 18, lift: 4)

                    // Notes list
                    if store.notes.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 28))
                                .foregroundStyle(.tertiary)
                            Text("No notes yet")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(MLColor.ink)
                            Text("Write your first note above to keep track of key concepts.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(26)
                        .stickerCard(radius: 18, lift: 4)
                    } else {
                        ForEach(store.notes) { note in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    Text(note.title)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(MLColor.ink)
                                    Spacer()
                                    Button {
                                        store.deleteNote(note.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(MLColor.coral)
                                            .frame(width: 32, height: 32)
                                            .background(Color.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
                                    }
                                    .accessibilityLabel("Delete note")
                                }
                                if !note.body.isEmpty {
                                    Text(note.body)
                                        .font(.footnote)
                                        .foregroundStyle(MLColor.ink.opacity(0.85))
                                        .lineSpacing(2)
                                }
                                HStack {
                                    if !note.tag.isEmpty {
                                        StickerBadge(text: note.tag, tone: MLColor.yellow, foreground: MLColor.ink)
                                    }
                                    Spacer()
                                    Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(14)
                            .stickerCard(radius: 16, lift: 3)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
        }
    }
}
