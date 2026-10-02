//
//  StickerDesignSystem.swift
//  MathLearn
//
//  1:1 port of the web app's Calm Botanical design system
//  (src/app/globals.css): soft off-white canvas, muted natural
//  greens, hairline borders, gentle diffuse shadows, pill buttons,
//  clean geometric type. Calm, balanced, approachable.
//  Every tone maps to the CSS custom property set.
//
//  Naming note: the tone SLOT names (coral/yellow/mint/blue/purple)
//  are kept 1:1 with the web CSS custom properties (--coral, --yellow,
//  …) so both platforms stay perfectly in sync — the slots now carry
//  the calm botanical values (coral slot = sage, mint slot =
//  eucalyptus, …), exactly as on the web.
//

import SwiftUI

// MARK: - Palette (mirrors globals.css :root)

enum MLColor {
    static let cream = Color(red: 0.969, green: 0.965, blue: 0.945)   // #F7F6F1 — soft warm off-white canvas
    static let ink = Color(red: 0.169, green: 0.208, blue: 0.180)     // #2B352E — deep green-slate
    static let coral = Color(red: 0.361, green: 0.478, blue: 0.373)   // #5C7A5F — sage, primary action
    static let yellow = Color(red: 0.871, green: 0.788, blue: 0.557)  // #DEC98E — oat honey, highlights
    static let mint = Color(red: 0.498, green: 0.663, blue: 0.549)    // #7FA98C — eucalyptus, success
    static let mintStrong = Color(red: 0.239, green: 0.420, blue: 0.310) // #3D6B4F — forest, small text/icons
    static let blue = Color(red: 0.498, green: 0.627, blue: 0.706)    // #7FA0B4 — dusty slate
    static let purple = Color(red: 0.490, green: 0.420, blue: 0.529)  // #7D6B87 — muted plum
    static let cardBackground = Color.white
}

// MARK: - Calm card (white, 1px hairline, 24px radius, soft diffuse shadow)

struct StickerCard: ViewModifier {
    var radius: CGFloat = 24
    var lift: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .background(MLColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(MLColor.ink.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: MLColor.ink.opacity(0.06), radius: 3, x: 0, y: 1)
            .shadow(color: MLColor.ink.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func stickerCard(radius: CGFloat = 24, lift: CGFloat = 6) -> some View {
        modifier(StickerCard(radius: radius, lift: lift))
    }
}

// MARK: - Pill button (52px, hairline edge, soft shadow, gentle press)

struct StickerButtonStyle: ButtonStyle {
    var tone: Color = MLColor.coral
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 26)
            .frame(minHeight: 52)
            .background(tone)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(MLColor.ink.opacity(0.14), lineWidth: 1))
            .shadow(color: MLColor.ink.opacity(configuration.isPressed ? 0.06 : 0.12),
                    radius: configuration.isPressed ? 2 : 6,
                    x: 0, y: configuration.isPressed ? 1 : 2)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(MLMotion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == StickerButtonStyle {
    static var stickerCoral: StickerButtonStyle { StickerButtonStyle() }
    static var stickerYellow: StickerButtonStyle { StickerButtonStyle(tone: MLColor.yellow, foreground: MLColor.ink) }
    static var stickerWhite: StickerButtonStyle { StickerButtonStyle(tone: .white, foreground: MLColor.ink) }
}

// MARK: - Small uppercase pill badge

struct StickerBadge: View {
    let text: String
    var tone: Color = MLColor.yellow
    var foreground: Color = MLColor.ink

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tone)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(MLColor.ink.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Tone system (Sticker.tsx Tone → bg/fg mapping)

enum Tone: String, CaseIterable {
    case coral, mint, blue, yellow, purple, white

    var bg: Color {
        switch self {
        case .coral: return MLColor.coral
        case .mint: return MLColor.mint
        case .blue: return MLColor.blue
        case .yellow: return MLColor.yellow
        case .purple: return MLColor.purple
        case .white: return .white
        }
    }

    var fg: Color {
        switch self {
        case .coral, .purple: return .white
        default: return MLColor.ink
        }
    }
}

// MARK: - Progress bar (Sticker.tsx StickerProgress)

struct StickerProgress: View {
    var value: Double        // 0...100
    var tone: Tone = .mint
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white)
                    .overlay(Capsule().strokeBorder(MLColor.ink.opacity(0.10), lineWidth: 1))
                Capsule()
                    .fill(tone.bg)
                    .frame(width: max(6, geo.size.width * min(1, max(0, value / 100))))
            }
        }
        .frame(height: height)
        .accessibilityValue("\(Int(value)) percent")
    }
}

// MARK: - Section header (badge + title + subtitle)

struct SectionHeader: View {
    var badgeText: String
    var badgeTone: Tone = .yellow
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            StickerBadge(text: badgeText, tone: badgeTone == .white ? MLColor.yellow : badgeTone.bg)
                .padding(.bottom, 2)
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(MLColor.ink)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Stat tile (DashboardView StatCell / ResultsCard ResultStat)

struct StatTile: View {
    var icon: String
    var tone: Tone
    var label: String
    var value: String
    var sub: String? = nil

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tone.fg)
                .frame(width: 34, height: 34)
                .background(tone == .white ? MLColor.cream : tone.bg.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(MLColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
            if let sub {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Difficulty selector (DifficultySelector.tsx)

struct DifficultyPills: View {
    @Binding var value: MathDifficulty

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MathDifficulty.allCases) { d in
                Button {
                    value = d
                } label: {
                    Text(d.label)
                        .font(.system(size: 12, weight: .semibold))
                        .textCase(.uppercase)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(value == d ? MLColor.coral : Color.white)
                        .foregroundStyle(value == d ? .white : MLColor.ink)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(MLColor.ink.opacity(value == d ? 0.10 : 0.14), lineWidth: 1))
                        .shadow(color: MLColor.ink.opacity(value == d ? 0.10 : 0.04), radius: value == d ? 4 : 2, x: 0, y: 1)
                }
            }
        }
        .animation(MLMotion.selection, value: value)
    }
}

// MARK: - Confetti burst (canvas-confetti port, light-weight)

struct ConfettiView: View {
    var trigger: Int
    @State private var pieces: [Piece] = []

    struct Piece: Identifiable {
        let id: Int
        let x: CGFloat        // 0...1 horizontal drift target
        let delay: Double
        let rotation: Double
        let color: Color
        let size: CGFloat
    }

    private let palette: [Color] = [MLColor.coral, MLColor.yellow, MLColor.mint, MLColor.blue, MLColor.purple]

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 1.6)
                    .rotationEffect(.degrees(p.rotation))
                    .modifier(FallModifier(delay: p.delay, targetX: p.x))
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in burst() }
        .onAppear { burst() }
    }

    private func burst() {
        pieces = (0..<42).map { i in
            Piece(
                id: i,
                x: CGFloat.random(in: 0.05...0.95),
                delay: Double.random(in: 0...0.35),
                rotation: Double.random(in: -160...160),
                color: palette[i % palette.count],
                size: CGFloat.random(in: 6...11)
            )
        }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            pieces = []
        }
    }

    private struct FallModifier: ViewModifier {
        let delay: Double
        let targetX: CGFloat
        @State private var fallen = false

        func body(content: Content) -> some View {
            content
                .offset(
                    x: UIScreen.main.bounds.width * (targetX - 0.5),
                    y: fallen ? UIScreen.main.bounds.height : -40
                )
                .opacity(fallen ? 0 : 1)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.8).delay(delay)) { fallen = true }
                }
        }
    }
}
