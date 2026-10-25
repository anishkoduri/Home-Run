import Foundation
import Testing
@testable import HomeRun

struct DemoRulesTests {
    @Test func counterofferStaysInsideTheDemoRange() {
        #expect(DemoRules.counterofferAllowed(100))
        #expect(DemoRules.counterofferAllowed(25_000))
        #expect(!DemoRules.counterofferAllowed(99))
        #expect(!DemoRules.counterofferAllowed(25_001))
    }

    @Test func refundCannotExceedWhatWasCaptured() {
        #expect(DemoRules.refundAllowed(captured: 800, alreadyRefunded: 0, amount: 800))
        #expect(!DemoRules.refundAllowed(captured: 800, alreadyRefunded: 800, amount: 800))
        #expect(!DemoRules.refundAllowed(captured: 800, alreadyRefunded: 0, amount: 801))
    }

    @Test func cancellationFollowsPickup() {
        #expect(DemoRules.cancellationEffect(status: .requested) == "release")
        #expect(DemoRules.cancellationEffect(status: .accepted) == "refund")
        #expect(DemoRules.cancellationEffect(status: .restaurantConfirmed) == "support")
        #expect(DemoRules.cancellationEffect(status: .pickedUp) == "support")
        #expect(DemoRules.cancellationEffect(status: .delivered) == "support-delivered")
    }

    @Test func quoteExpiresAtTheEarlierDeadline() {
        let submitted = Date(timeIntervalSince1970: 1_700_000_000)
        let soon = submitted.addingTimeInterval(10 * 60)
        let later = submitted.addingTimeInterval(40 * 60)
        #expect(DemoRules.quoteDeadline(submitted: submitted, cutoff: soon) == soon)
        #expect(DemoRules.quoteDeadline(submitted: submitted, cutoff: later) == submitted.addingTimeInterval(15 * 60))
    }

    @Test func runnerKeepsTheDistanceAndHomeRunKeepsFifteenPercent() {
        #expect(PricingPolicy.scaled(200) == 120)
        #expect(PricingPolicy.markedUp(120) == 138)
        #expect(DemoRules.runnerShare(of: 138) == 120)
        #expect(PricingPolicy.markupBasisPoints == 1_500)
    }

    @Test func sharedStopDiscountStaysOff() {
        #expect(PricingPolicy.sharedStopDiscountCents == 200)
        #expect(PricingPolicy.sharedStopDiscountEnabled == false)
    }

    @Test func moreThanThirtyExtraMinutesNeedsReview() {
        let result = PricingPolicy.evaluate(PricingPolicy.Input(
            extraMeters: 1609.344,
            extraSeconds: 31 * 60,
            weightPounds: 5,
            weightConfirmed: true,
            bulky: false,
            agreedWaitingMinutes: 0
        ))
        if case .manualReview = result {
            #expect(Bool(true))
        } else {
            Issue.record("Expected a manual review")
        }
    }
}
