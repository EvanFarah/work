//
//  MathLearnApp.swift
//  MathLearn
//
//  Native SwiftUI port of the MathLearn web app (Next.js → SwiftUI).
//  Entry point: onboarding gate → zero-press funnel → main app.
//  StudyStore + CatalogService + SubscriptionService + AIService are
//  injected once here and shared by every feature.
//

import SwiftUI

@main
struct MathLearnApp: App {
    @StateObject private var subscription = SubscriptionService()
    @StateObject private var store = StudyStore()
    @StateObject private var catalog = CatalogService()
    @StateObject private var ai = AIService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(subscription)
                .environmentObject(store)
                .environmentObject(catalog)
                .environmentObject(ai)
                .preferredColorScheme(.light) // funnel + app share the cream sticker palette
                .tint(MLColor.coral)
        }
    }
}
