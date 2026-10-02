//
//  Glass.swift
//  MathLearn
//
//  The ONLY place Liquid Glass / OS-gated visual APIs are adopted.
//  Every availability-gated call in the app lives here as a no-op-on-
//  older-OS modifier, so iOS 17–25 render exactly the pre-glass sticker
//  design (GLASS-BOUNDARIES.md §7). Never scatter `if #available` in
//  feature views, never wrap glassEffect in a generic `.if` helper
//  (structural-identity destruction — skill hard rule).
//
//  Rules encoded here, from the installed liquid-glass skills:
//   • shapes go in glassEffect(_:in:) — never clipShape on a glass view
//   • hit areas restated with a matching contentShape
//   • no opacity < 1 on any glass view or ancestor
//   • no custom shadows/borders/tints on glass — the system owns the edge
//   • morphs run only through system animations at the mutation site
//   • ≥2 coexisting glass surfaces share ONE GlassEffectContainer
//

import SwiftUI

// MARK: - Container (one container per glass cluster)

private struct GlassContainerModifier: ViewModifier {
    var spacing: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    /// Groups the glass surfaces of one screen so the system can merge,
    /// sample, and morph them correctly. No-op below iOS 26.
    func mlGlassContainer(spacing: CGFloat = 8) -> some View {
        modifier(GlassContainerModifier(spacing: spacing))
    }
}

// MARK: - G3 surfaces (the only custom glass in the app)

/// Funnel back control: iOS 26 → `.regular` glass capsule with a restated
/// capsule hit area; pre-26 → today's exact white circle + hairline border.
private struct FunnelBackGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: Capsule())
                .contentShape(Capsule())
        } else {
            content
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(MLColor.ink.opacity(0.15), lineWidth: 1))
        }
    }
}

/// Funnel Skip control: iOS 26 → padded `.regular` glass pill with a
/// restated hit area; pre-26 → unchanged (plain secondary text, zero
/// layout delta).
private struct FunnelSkipGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .glassEffect(.regular, in: Capsule())
                .contentShape(Capsule())
        } else {
            content
        }
    }
}

extension View {
    /// G3 back-button capsule. No tint, no border, no shadow on glass.
    func mlFunnelBackGlass() -> some View {
        modifier(FunnelBackGlassModifier())
    }

    /// G3 Skip pill (~70×32pt). Padding is iOS-26-only so the pre-26
    /// layout stays byte-identical.
    func mlFunnelSkipGlass() -> some View {
        modifier(FunnelSkipGlassModifier())
    }
}

// MARK: - M1 morph identity + Reduce Motion style

private struct GlassIDModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffectID(id, in: namespace)
        } else {
            content
        }
    }
}

private struct GlassMorphStyleModifier: ViewModifier {
    var reduceMotion: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), reduceMotion {
            content.glassEffectTransition(.materialize)
        } else {
            content
        }
    }
}

extension View {
    /// Tags a glass surface for the container's morph graph (M1: the
    /// conditional funnel back control). No-op below iOS 26.
    func mlGlassID(_ id: String, in namespace: Namespace.ID) -> some View {
        modifier(GlassIDModifier(id: id, namespace: namespace))
    }

    /// Reduce Motion morph style: appear/disappear in place instead of
    /// travelling between shapes. Motion path: no-op (system morph).
    func mlGlassMorphStyle(reduceMotion: Bool) -> some View {
        modifier(GlassMorphStyleModifier(reduceMotion: reduceMotion))
    }
}

// MARK: - G4 toolbar exemption (sticker circle must not ride the glass bar)

private struct ToolbarSharedBackgroundHiddenModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.sharedBackgroundVisibility(.hidden)
        } else {
            content
        }
    }
}

extension View {
    /// Hides the system toolbar's shared glass background for this item so
    /// the white sticker More-circle never sits ON glass (glass-on-glass
    /// ban, spec G4). No-op below iOS 26.
    func mlToolbarSharedBackgroundHidden() -> some View {
        modifier(ToolbarSharedBackgroundHiddenModifier())
    }
}

// MARK: - G1 tab bar minimize (the only scroll-linked chrome change)

private struct TabBarMinimizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

extension View {
    /// System tab bar minimizes on scroll-down, restores on scroll-up.
    /// No custom scrims, no scroll-edge overrides, no per-frame state.
    func mlTabBarMinimizeOnScroll() -> some View {
        modifier(TabBarMinimizeModifier())
    }
}

// MARK: - Bar chrome unification (bottom bar = top bar style)
//
// User-approved amendment (2026-09-27) to the "zero toolbarBackground"
// migration audit: the original rule banned scrims that fought Liquid
// Glass. This is the opposite move — nav bars AND the tab bar get ONE
// shared chrome style (cream, always visible), so the bottom bar matches
// the top bars on every OS version. On iOS 26 the color composes with
// the system glass (both bars tinted identically); below 26 both render
// solid cream. No scrims, no appearance proxies, no scroll-edge overrides.

private struct MatchingBarChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(MLColor.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(MLColor.cream, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}

extension View {
    /// Bottom tab bar shares the top bars' exact chrome style. Apply once
    /// on MainTabView so every embedded NavigationStack inherits it.
    func mlMatchingBarChrome() -> some View {
        modifier(MatchingBarChromeModifier())
    }
}

// MARK: - M4 sheet zoom (iOS 18-gated delight; standard sheet below 18)

private struct ZoomSourceModifier: ViewModifier {
    var active: Bool
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), active {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

private struct ZoomTargetModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

extension View {
    /// Marks a More-sheet row as the zoom origin of its sheet (M4).
    /// Inert when `active` is false or below iOS 18.
    func mlZoomSource(_ active: Bool, id: String, in namespace: Namespace.ID) -> some View {
        modifier(ZoomSourceModifier(active: active, id: id, namespace: namespace))
    }

    /// Marks a presented sheet as the zoom destination (M4).
    /// Standard system sheet below iOS 18.
    func mlZoomTarget(id: String, in namespace: Namespace.ID) -> some View {
        modifier(ZoomTargetModifier(id: id, namespace: namespace))
    }
}
