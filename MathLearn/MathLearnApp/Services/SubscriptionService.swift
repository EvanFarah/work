//
//  SubscriptionService.swift
//  MathLearn
//
//  Port of src/lib/subscription/service.ts. Persists the active tier +
//  7-day trial state in UserDefaults (the web app uses localStorage).
//  The zero-press onboarding funnel calls startTrial(...) automatically.
//

import Foundation
import Combine

@MainActor
final class SubscriptionService: ObservableObject {
    private static let tierKey = "mathlearn.plan"
    private static let trialStartKey = "mathlearn.trialStart"

    @Published private(set) var plan: PlanId
    @Published private(set) var trialStartDate: Date?

    /// Trial entitlement: 7 free days from trial start (or none).
    var isInTrial: Bool {
        guard let start = trialStartDate else { return false }
        return Date().timeIntervalSince(start) < 7 * 24 * 3600
    }

    /// The tier actually in effect: trial promotes Plus/Premium selection.
    var effectivePlan: PlanId {
        isInTrial && plan == .free ? .premium : plan
    }

    init() {
        let defaults = UserDefaults.standard
        let raw = defaults.string(forKey: Self.tierKey) ?? PlanId.free.rawValue
        plan = PlanId(rawValue: raw) ?? .free
        trialStartDate = defaults.object(forKey: Self.trialStartKey) as? Date
    }

    /// Start the 7-day free trial on the chosen plan (funnel auto-fires this).
    func startTrial(plan: PlanId) {
        self.plan = plan
        if trialStartDate == nil { trialStartDate = Date() }
        persist()
    }

    func setPlan(_ plan: PlanId) {
        self.plan = plan
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(plan.rawValue, forKey: Self.tierKey)
        if let trialStartDate {
            UserDefaults.standard.set(trialStartDate, forKey: Self.trialStartKey)
        }
    }
}
