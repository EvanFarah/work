//
//  AITutorView.swift
//  MathLearn
//
//  Port of AIChatView.tsx — the AI chat tutor. Talks to the web
//  backend's /api/chat via AIService (shared brain with the web app)
//  and degrades to the built-in offline tutor when the backend is
//  unreachable, so the feature always works.
//

import SwiftUI

struct AITutorView: View {
    @EnvironmentObject private var ai: AIService
    @EnvironmentObject private var subscription: SubscriptionService
    @EnvironmentObject private var store: StudyStore

    struct Message: Identifiable, Equatable {
        let id = UUID()
        let role: String
        let content: String
    }

    @State private var messages: [Message] = []
    @State private var input = ""
    @State private var loading = false
    @State private var usedServer = true
    @FocusState private var inputFocused: Bool

    private let suggestions = [
        "How do I factor x² − 9?",
        "Explain the chain rule with an example",
        "What's the difference between mean and median?",
        "Solve: 2x + 5 = 17",
    ]

    private var quota: (used: Int, limit: Int) {
        let plan = Plan.by(id: subscription.effectivePlan)
        let used = min(store.stats.totalAnswered / 3, plan.aiChats)
        return (used, plan.aiChats)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MLColor.cream.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    chatWindow
                    inputBar
                }
            }
            .navigationTitle("AI Tutor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { MoreToolbarButton() } }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                StickerBadge(text: usedServer ? "✨ StepFun 3.5" : "📱 Offline tutor", tone: MLColor.coral, foreground: .white)
                Spacer()
                StickerBadge(text: "AI chats \(quota.used)/\(quota.limit)", tone: .white)
            }
            Text("Ask any math question — I'll show every step.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: Chat window

    private var chatWindow: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    if messages.isEmpty {
                        emptyState
                    }
                    ForEach(messages) { message in
                        bubble(message).id(message.id)
                    }
                    if loading {
                        typingIndicator
                    }
                }
                .padding(16)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 26))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(MLColor.coral)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .stickerCard(radius: 18, lift: 5)
            Text("Ask me anything about math")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(MLColor.ink)
            Text("I'll explain concepts, solve problems, and show every step.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // Suggestion chips
            ForEach(suggestions, id: \.self) { s in
                Button {
                    send(s)
                } label: {
                    Text(s)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.white)
                        .foregroundStyle(MLColor.ink)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(MLColor.ink.opacity(0.18), lineWidth: 1.5))
                        .shadow(color: MLColor.ink.opacity(0.4), radius: 0, x: 0, y: 2)
                }
            }
        }
        .padding(.top, 20)
    }

    private func bubble(_ message: Message) -> some View {
        let isUser = message.role == "user"
        let avatar = Image(systemName: isUser ? "person.fill" : "brain.head.profile")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(isUser ? MLColor.ink : .white)
            .frame(width: 30, height: 30)
            .background(isUser ? MLColor.blue : MLColor.coral)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        let content = Text(message.content)
            .font(.footnote)
            .foregroundStyle(MLColor.ink)
            .lineSpacing(2)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isUser ? MLColor.blue.opacity(0.35) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1.5))
        return HStack(alignment: .top, spacing: 8) {
            if isUser {
                Spacer(minLength: 30)
                content
                avatar
            } else {
                avatar
                content
                Spacer(minLength: 30)
            }
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(MLColor.coral)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 6, height: 6)
                        .modifier(PulseModifier(delay: Double(i) * 0.2))
                }
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer()
        }
    }

    // MARK: Input bar

    private var inputBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                TextField("Ask a math question…", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MLColor.ink.opacity(0.18), lineWidth: 1.5))
                    .focused($inputFocused)
                    .onSubmit { send(input) }

                Button {
                    send(input)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.stickerCoral)
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || loading)
            }

            if !messages.isEmpty {
                Button {
                    messages = []
                } label: {
                    Label("Clear chat", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(MLColor.cream)
    }

    // MARK: Engine

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !loading else { return }
        input = ""
        inputFocused = false
        messages.append(Message(role: "user", content: trimmed))
        loading = true
        Task {
            let payload = messages.map { AIService.ChatMessage(role: $0.role, content: $0.content) }
            let (reply, server) = await ai.chat(payload)
            usedServer = server
            messages.append(Message(role: "assistant", content: reply))
            loading = false
        }
    }
}

// MARK: - Typing pulse

private struct PulseModifier: ViewModifier {
    let delay: Double
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .opacity(on ? 1 : 0.3)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(delay)) {
                    on = true
                }
            }
    }
}
