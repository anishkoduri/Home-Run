import Testing
@testable import HomeRun

@Suite("Delivery price")
struct PricingPolicyTests {
    private func quoted(_ input: PricingPolicy.Input) -> PricingPolicy.Quote {
        guard case .quoted(let quote) = PricingPolicy.evaluate(input) else {
            Issue.record("Expected a quote")
            return PricingPolicy.Quote(version: "", baseCents: 0, routeCents: 0, weightCents: 0, waitingCents: 0, bulkyCents: 0, totalCents: 0, runnerShareCents: 0)
        }
        return quote
    }

    @Test("No extra distance is the stop plus 15%")
    func ordinary() {
        let quote = quoted(.init(extraMeters: 0, extraSeconds: 0, weightPounds: 2, weightConfirmed: true, bulky: false, agreedWaitingMinutes: 0))
        #expect(quote.runnerShareCents == 120)
        #expect(quote.totalCents == 138)
        #expect(quote.totalCents - quote.runnerShareCents == 18)
    }

    @Test("One mile and five minutes adds distance")
    func boundary() {
        let quote = quoted(.init(extraMeters: 1609.344, extraSeconds: 300, weightPounds: 2, weightConfirmed: true, bulky: false, agreedWaitingMinutes: 0))
        #expect(quote.routeCents == 115)
        #expect(quote.runnerShareCents == 189)
        #expect(quote.totalCents == 217)
    }

    @Test("Six miles and twelve minutes")
    func detour() {
        let quote = quoted(.init(extraMeters: 1609.344 * 6, extraSeconds: 12 * 60, weightPounds: 2, weightConfirmed: true, bulky: false, agreedWaitingMinutes: 0))
        #expect(quote.runnerShareCents == 372)
        #expect(quote.totalCents == 428)
    }

    @Test("Thirty-five pounds on a standard route")
    func heavy() {
        let quote = quoted(.init(extraMeters: 0, extraSeconds: 0, weightPounds: 35, weightConfirmed: true, bulky: false, agreedWaitingMinutes: 0))
        #expect(quote.runnerShareCents == 360)
        #expect(quote.totalCents == 414)
    }

    @Test("Bulky chair on a standard route")
    func bulkyChair() {
        let quote = quoted(.init(extraMeters: 0, extraSeconds: 0, weightPounds: 20, weightConfirmed: true, bulky: true, agreedWaitingMinutes: 0))
        #expect(quote.runnerShareCents == 480)
        #expect(quote.totalCents == 552)
    }

    @Test("Ten minutes of agreed waiting")
    func waiting() {
        let quote = quoted(.init(extraMeters: 0, extraSeconds: 0, weightPounds: 2, weightConfirmed: true, bulky: false, agreedWaitingMinutes: 10))
        #expect(quote.runnerShareCents == 150)
        #expect(quote.totalCents == 173)
    }

    @Test("Unconfirmed or heavy weight is not priced as zero")
    func review() {
        #expect(PricingPolicy.evaluate(.init(extraMeters: 0, extraSeconds: 0, weightPounds: nil, weightConfirmed: false, bulky: false, agreedWaitingMinutes: 0)) != .quoted(quoted(.init(extraMeters: 0, extraSeconds: 0, weightPounds: 1, weightConfirmed: true, bulky: false, agreedWaitingMinutes: 0))))
        if case .manualReview = PricingPolicy.evaluate(.init(extraMeters: 0, extraSeconds: 0, weightPounds: 51, weightConfirmed: true, bulky: false, agreedWaitingMinutes: 0)) {
        } else {
            Issue.record("Expected manual review")
        }
    }
}
