import Foundation

/// Price arithmetic for the AI Premium page. Pure, so the promises the page
/// makes ("save 52%", "1 week free") are testable.
enum PlanPricing {
    /// How much cheaper a year is than twelve months, rounded to the nearest
    /// whole percent; nil when the yearly plan saves nothing.
    static func savingsPercent(monthly: Decimal, yearly: Decimal) -> Int? {
        guard monthly > 0 else { return nil }
        let fullYear = monthly * 12
        guard yearly < fullYear else { return nil }
        var ratio = (fullYear - yearly) / fullYear * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &ratio, 0, .plain)
        let percent = NSDecimalNumber(decimal: rounded).intValue
        return percent > 0 ? percent : nil
    }

    static func perMonth(yearly: Decimal) -> Decimal {
        yearly / 12
    }

    /// Only promise a trial the learner can still start (one per subscription group).
    static func showsTrial(_ product: StoreProduct) -> Bool {
        product.trialDays != nil && product.isTrialEligible
    }
}
