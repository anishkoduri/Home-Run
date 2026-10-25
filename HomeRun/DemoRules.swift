import Foundation

struct LedgerEntry: Codable, Identifiable, Equatable {
    var id: String
    var operationKey: String
    var orderId: String
    var kind: String
    var cents: Int
    var createdAt: String
}

struct AppNotice: Codable, Identifiable, Equatable {
    var id: String
    var recipientId: String
    var type: String
    var orderId: String?
    var tripId: String?
    var title: String
    var body: String
    var createdAt: String
    var readAt: String?
    var dedupeKey: String
}

struct AttachmentPayload: Codable, Equatable {
    var jpegBase64: String?
}

struct ComposerDraft: Codable, Equatable {
    var tripId: String
    var placeId: String
    var requestText: String
    var merchandise: String
    var substitution: String
    var instructions: String
    var personal: Bool
    var bulky: Bool
    var hasScreenshot: Bool
    var screenshotBase64: String? = nil
}

struct ScenarioPrep: Codable, Equatable {
    var scenario: Int
    var title: String
    var instructions: String
    var city: String
    var fixture: String
    var forceSamples: Bool
    var clearTerms: Bool
}

struct SavedRequest: Codable, Identifiable, Equatable {
    var id: String
    var customerId: String
    var city: String
    var placeName: String?
    var maxFeeCents: Int?
    var status: String
    var matchedTripId: String?
    var createdAt: String
}

struct SavedPlace: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var userId: String
    var placeId: String
    var name: String
    var address: String
    var lat: Double
    var lng: Double
    var city: String
    var photoName: String?
    var photoCredit: String?
    var contentSource: String?
    var createdAt: String
}

struct SavedPlaceList: Codable { var places: [SavedPlace] }

struct SupportCase: Codable, Identifiable, Equatable {
    var id: String
    var actorId: String
    var orderId: String?
    var category: String
    var details: String
    var status: String
    var resolution: String?
    var createdAt: String
}

struct NoticeList: Codable { var notices: [AppNotice] }
struct SavedRequestList: Codable { var requests: [SavedRequest] }
struct SupportList: Codable { var cases: [SupportCase] }
struct LedgerList: Codable { var entries: [LedgerEntry] }

enum DemoRules {
    static let termsVersion = "demo-1"
    static let counterofferRange = 100...25_000

    static func counterofferAllowed(_ cents: Int) -> Bool {
        counterofferRange.contains(cents)
    }

    static func runnerShare(of cents: Int) -> Int {
        PricingPolicy.halfUp(Decimal(cents) * Decimal(PricingPolicy.runnerBasisPoints) / 10_000)
    }

    /// Delivery-fee effect only. Runner-purchase history keeps the older support stop once a purchase was recorded.
    static func cancellationEffect(status: OrderStatus, orderingModel: String? = nil) -> String {
        if orderingModel == "customer_paid" || orderingModel == "personal" {
            switch status {
            case .requested: return "release"
            case .accepted, .restaurantConfirmed: return "refund"
            case .pickedUp, .onTheWay, .arriving: return "support"
            case .delivered: return "support-delivered"
            default: return "none"
            }
        }
        switch status {
        case .requested: return "release"
        case .accepted: return "refund"
        case .restaurantConfirmed, .pickedUp, .onTheWay, .arriving: return "support"
        case .delivered: return "support-delivered"
        default: return "none"
        }
    }

    static func quoteDeadline(submitted: Date, cutoff: Date) -> Date {
        min(submitted.addingTimeInterval(15 * 60), cutoff)
    }

    static func refundAllowed(captured: Int, alreadyRefunded: Int, amount: Int) -> Bool {
        amount > 0 && amount <= captured - alreadyRefunded
    }
}
