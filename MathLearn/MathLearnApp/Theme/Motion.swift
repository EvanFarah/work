//
//  Motion.swift
//  MathLearn
//
//  Named motion vocabulary for the whole app (apple-motion-feel skill).
//  Nothing else in the app may hand-tune a spring: new motion joins this
//  table. Every animated component reads its curve from here so response
//  and damping stay consistent, and Reduce Motion is honored PER COMPONENT
//  (spec §5/§8) — never with one app-root check.
//

import SwiftUI

enum MLMotion {
    /// Tap/press feedback — near-critically damped. A tap wants no wobble
    /// (damping table: tap → 1.0; 0.9 leaves a hint of life without the
    /// overshoot the old 0.7 produced). Replaces the hand-tuned 0.7.
    static let press = Animation.spring(response: 0.25, dampingFraction: 0.9)

    /// Selection changes: hub tab lens, difficulty pills, timer crossfade,
    /// quiz/game phase swaps.
    static let selection = Animation.snappy

    /// Onboarding page advance and the funnel back-control morph.
    /// Same value as the pre-existing hand-tuned pager spring — now named.
    static let page = Animation.spring(response: 0.45, dampingFraction: 0.9)

    /// Flashcard flip. Same value as the pre-existing hand-tuned spring —
    /// now named so no call site carries a raw curve.
    static let flip = Animation.spring(response: 0.35, dampingFraction: 0.8)

    /// Celebration moments (XP banked, confetti trigger).
    static let celebrate = Animation.bouncy

    /// Gentle crossfade used as the Reduce Motion branch: no wobble,
    /// no scale, no travel. Vestibular-safe by construction.
    static let crossfade = Animation.easeInOut(duration: 0.2)

    /// Returns `animation`, or nil when Reduce Motion asks for an
    /// instant change (paired with a crossfade branch where the spec
    /// requires one: M1 materialize, M3 opacity, flashcard flip).
    /// Usage: `withAnimation(MLMotion.adaptive(MLMotion.selection, reduceMotion: reduceMotion)) { … }`
    static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    /// M3 phase swaps (intro → active → results, pick ↔ drill, game phases).
    /// Motion: asymmetric — insert opacity + scale 0.96, remove opacity.
    /// Reduce Motion: plain crossfade (spec §8).
    static func phaseTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.96)),
                removal: .opacity
            )
    }
}
