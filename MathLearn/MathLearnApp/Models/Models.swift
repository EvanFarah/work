//
//  Models.swift
//  MathLearn
//
//  Subscription plans, mirroring src/lib/subscription/plans.ts.
//  (Domain models live in StudyModels.swift / CatalogModels.swift.)
//

import Foundation

// MARK: - Subscription (src/lib/subscription/plans.ts)

enum PlanId: String, Codable, CaseIterable {
    case free
    case plus
    case premium
}

struct Plan: Identifiable {
    let id: PlanId
    let name: String
    let monthlyPrice: Decimal
    let annualMonthlyEquivalent: Decimal
    let quizzes: Int
    let aiChats: Int
    /// Premium-only: Live Work Check runs per month (0 = not in tier).
    let liveChecks: Int
    /// PPT Maker decks per month (every tier includes the PPT maker).
    let pptDecks: Int

    static let all: [Plan] = [
        Plan(id: .free, name: "Free", monthlyPrice: 0, annualMonthlyEquivalent: 0, quizzes: 20, aiChats: 200, liveChecks: 0, pptDecks: 5),
        Plan(id: .plus, name: "Plus", monthlyPrice: 5.99, annualMonthlyEquivalent: 3.29, quizzes: 100, aiChats: 1000, liveChecks: 0, pptDecks: 50),
        Plan(id: .premium, name: "Premium", monthlyPrice: 6.99, annualMonthlyEquivalent: 3.84, quizzes: 500, aiChats: 5000, liveChecks: 2500, pptDecks: 100),
    ]

    static func by(id: PlanId) -> Plan { all.first { $0.id == id } ?? all[0] }

    // ── Feature tier gates (2026-09-27 map) ──
    /// Free: every question's hint surfaces itself as teaching — the method
    /// is on the card automatically, no button to hunt for.
    var includesAutoLearnHints: Bool { true }
    /// Free: the PPT Maker ships on every tier (quota = pptDecks / month).
    var includesPPTMaker: Bool { true }
    /// Plus+: press "Explain why wrong" after solving → instant analysis.
    var includesMistakeAnalyzer: Bool { id.rank >= PlanId.plus.rank }
    /// Plus+: forgetting-curve predictions per topic, with %.
    var includesLikelyToForget: Bool { id.rank >= PlanId.plus.rank }
    /// Premium only: scans ALL mistakes app-wide for recurring misconception types.
    var includesMisconceptionDetector: Bool { id == .premium }
    /// Premium only: Live Work Check — validates your working line by line,
    /// flagging sign / calculation / place-value slips the moment you write them.
    var includesLiveWorkCheck: Bool { id == .premium }
}

// MARK: - Month-keyed usage counter (quota accounting)

/// Small UserDefaults counter keyed per calendar month — powers the PPT
/// Maker deck quota (free 5/mo) and Live Work Check runs (premium 2,500/mo).
/// Resets itself the first time it is read in a new month.
struct FeatureUsage {
    let feature: String

    private var monthKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    private var storageKey: String { "mathlearn.usage.\(feature).\(monthKey)" }

    func used() -> Int { UserDefaults.standard.integer(forKey: storageKey) }

    @discardableResult
    func increment() -> Int {
        let next = used() + 1
        UserDefaults.standard.set(next, forKey: storageKey)
        return next
    }

    /// Remaining quota this month (nil = effectively unlimited).
    func remaining(quota: Int) -> Int? { quota <= 0 ? nil : max(0, quota - used()) }
}

/// Rank used for tier gating (trial promotes to premium — SubscriptionService).
extension PlanId {
    var rank: Int {
        switch self {
        case .free: return 0
        case .plus: return 1
        case .premium: return 2
        }
    }

    static func < (lhs: PlanId, rhs: PlanId) -> Bool { lhs.rank < rhs.rank }
}
