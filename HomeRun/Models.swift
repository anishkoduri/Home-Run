import Foundation

enum OrderStatus: String, Codable, CaseIterable {
    case requested, accepted, restaurantConfirmed = "restaurant_confirmed"
    case pickedUp = "picked_up", onTheWay = "on_the_way", arriving, delivered, declined, cancelled

    var label: String {
        switch self {
        case .requested: return "Awaiting runner"
        case .accepted: return "Runner accepted"
        case .restaurantConfirmed: return "Pickup details ready"
        case .pickedUp: return "Picked up"
        case .onTheWay: return "En route"
        case .arriving: return "Arriving"
        case .delivered: return "Delivered"
        case .declined: return "Declined"
        case .cancelled: return "Cancelled"
        }
    }

    var tone: Tone {
        switch self {
        case .requested: return .pending
        case .delivered: return .completed
        case .declined, .cancelled: return .closed
        default: return .active
        }
    }

    var isTerminal: Bool { self == .delivered || self == .declined || self == .cancelled }
    var isActiveDelivery: Bool { self == .accepted || self == .restaurantConfirmed || self == .pickedUp || self == .onTheWay || self == .arriving }

    enum Tone { case pending, active, completed, closed }

    var driverNext: (OrderStatus, String)? {
        switch self {
        case .accepted: return nil
        case .restaurantConfirmed: return (.pickedUp, "Mark picked up")
        case .pickedUp: return (.onTheWay, "Start travel")
        case .onTheWay: return (.arriving, "I'm arriving")
        default: return nil
        }
    }

    var customerCanCancel: Bool { self == .requested || self == .accepted }
    var driverCanCancel: Bool { self == .accepted }
}

struct SessionUser: Codable, Equatable {
    var id: String
    var email: String
}

enum AccountUse: String, Codable, CaseIterable, Identifiable {
    case order, deliver, both
    var id: String { rawValue }

    var title: String {
        switch self {
        case .order: return "I want to order"
        case .deliver: return "I want to deliver"
        case .both: return "Both"
        }
    }

    var detail: String {
        switch self {
        case .order: return "Start on ordering. You can still bring food with this account."
        case .deliver: return "Start on bringing food. You can still order with this account."
        case .both: return "Start on ordering. Switch to bringing food whenever you are driving."
        }
    }
}

struct Profile: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var avatarUrl: String?
    var paymentHandle: String?
    var createdAt: String?
    var intent: String?
    var termsVersion: String? = nil
    var termsAcceptedAt: String? = nil
    var notify: Bool? = nil

    var use: AccountUse { AccountUse(rawValue: intent ?? "") ?? .both }
}

struct TripStop: Codable, Identifiable, Equatable {
    var id: String?
    var tripId: String?
    var placeId: String?
    var restaurantName: String
    var address: String?
    var lat: Double
    var lng: Double
    var stopOrder: Int
    var kind: String? = nil
    var available: Bool? = nil
    var arrivesAt: String? = nil
}

struct Trip: Codable, Identifiable, Equatable {
    var id: String
    var driverId: String
    var originCity: String
    var originLat: Double
    var originLng: Double
    var destinationCity: String
    var destinationLat: Double
    var destinationLng: Double
    var departureAt: String
    var maxOrders: Int
    var notes: String?
    var status: String
    var cutoffAt: String? = nil
    var maxItemPounds: Double? = nil
    var maxTotalPounds: Double? = nil
    var allowsCustom: Bool? = nil
    var maxDetourMinutes: Double? = nil
    var maxDetourMiles: Double? = nil
    var recurrence: String? = nil
    var templateId: String? = nil
    /// Set when this generated date was edited on its own. Series updates leave it alone.
    var occurrenceEdited: Bool? = nil
    var etaAt: String? = nil
    var createdAt: String
    var driver: Profile?
    var stops: [TripStop]?
    var activeOrders: Int?
}

struct Order: Codable, Identifiable, Equatable {
    var id: String
    var tripId: String
    var customerId: String
    var driverId: String
    var restaurantPlaceId: String?
    var restaurantName: String
    var restaurantAddress: String?
    var restaurantLat: Double
    var restaurantLng: Double
    var restaurantWebsite: String?
    var placeSource: String?
    var destinationType: String
    var destinationLabel: String
    var destinationLat: Double
    var destinationLng: Double
    var detourMinutes: Double?
    var deliveryFee: Double?
    var estimateSource: String?
    var estimatedArrivalAt: String?
    var customerNote: String?
    var itemSummary: String?
    var quoteCents: Int?
    var runnerShareCents: Int?
    var quoteState: String?
    var quoteExpiresAt: String? = nil
    var operationKey: String? = nil
    var weightPounds: Double? = nil
    var counterCents: Int? = nil
    var counterReason: String? = nil
    var counterExpiresAt: String? = nil
    var previousQuoteCents: Int? = nil
    var declineReason: String? = nil
    var lines: [OrderLine]? = nil
    var merchandiseCents: Int? = nil
    var substitution: String? = nil
    var personalItem: Bool? = nil
    var purchaseState: String? = nil
    var actualMerchandiseCents: Int? = nil
    var revisionMerchandiseCents: Int? = nil
    var screenshotName: String? = nil
    /// customer_paid, personal, or runner_purchase. Older merchandise ledgers stay runner_purchase.
    var orderingModel: String? = nil
    var alreadyOrdered: Bool? = nil
    var handoffSubmittedAt: String? = nil
    var detailsReviewedAt: String? = nil
    var detailsChangedAt: String? = nil
    var referenceMissing: Bool? = nil
    var pickupCode: String? = nil
    var contactLabel: String? = nil
    var accessInstructions: String? = nil
    var pickupWindowLabel: String? = nil
    var pendingWindowLabel: String? = nil
    var pendingReadyAt: String? = nil
    var pendingRestaurantName: String? = nil
    var placeChangePending: Bool? = nil
    var itemQuantity: String? = nil
    var fragile: Bool? = nil
    var bulkyItem: Bool? = nil
    var offerRunnerId: String? = nil
    var offerCents: Int? = nil
    var offerShareCents: Int? = nil
    var offerExpiresAt: String? = nil
    var offerTripId: String? = nil
    var offerDistanceKind: String? = nil
    var offerMeters: Double? = nil
    var offerSeconds: Double? = nil
    var offerIncremental: Bool? = nil
    var pickupCity: String? = nil
    var pickupUnit: String? = nil
    var locationResolved: Bool? = nil
    var feeLockedCents: Int? = nil
    var confirmationPin: String?
    var pinAttempts: Int?
    var pickupName: String?
    var restaurantOrderNumber: String?
    var pickupReadyAt: String?
    var pickupInstructions: String?
    var status: OrderStatus
    var cancelledBy: String?
    var acceptedAt: String?
    var restaurantOrderConfirmedAt: String?
    var pickedUpAt: String?
    var onTheWayAt: String?
    var deliveredAt: String?
    var declinedAt: String?
    var cancelledAt: String?
    var createdAt: String
    var updatedAt: String
    var trip: Trip?
    var driver: Profile?
    var customer: Profile?
}

extension Order {
    var isRunnerPurchase: Bool {
        orderingModel == "runner_purchase" || (orderingModel == nil && merchandiseCents != nil)
    }

    var usesCustomerHandoff: Bool {
        orderingModel == "customer_paid" || orderingModel == "personal"
    }

    var isPersonalPickup: Bool { orderingModel == "personal" }

    var handoffComplete: Bool { handoffSubmittedAt != nil }

    var needsHandoffForm: Bool {
        guard usesCustomerHandoff, !handoffComplete else { return false }
        if isPersonalPickup { return status == .accepted }
        return status == .requested || status == .accepted
    }

    var canEditHandoff: Bool {
        usesCustomerHandoff && handoffComplete && (status == .accepted || status == .restaurantConfirmed)
    }

    var detailsNeedReview: Bool {
        guard handoffComplete else { return false }
        guard let reviewed = detailsReviewedAt else { return true }
        guard let changed = detailsChangedAt else { return false }
        return changed > reviewed
    }

    var progressTitle: String {
        if isRunnerPurchase {
            if status == .accepted && purchaseState != "placed" { return "Accepted — purchase not placed" }
            if purchaseState == "revision" { return "Merchandise total changed" }
            if status == .restaurantConfirmed { return "Purchase placed" }
            return status.label
        }
        switch status {
        case .requested:
            if offerRunnerId != nil && driverId.isEmpty { return "Delivery offer waiting" }
            return "Awaiting runner"
        case .accepted: return handoffComplete ? "Pickup details ready" : "Awaiting pickup details"
        case .restaurantConfirmed:
            if isPersonalPickup && detailsNeedReview { return "Pickup arranged" }
            if detailsNeedReview { return "Pickup details ready" }
            return "Runner reviewed details"
        case .onTheWay: return "En route"
        default: return status.label
        }
    }

    var customerMayCancel: Bool {
        if isRunnerPurchase { return status == .requested || status == .accepted }
        return status == .requested || status == .accepted || status == .restaurantConfirmed
    }

    var driverMayCancel: Bool {
        if isRunnerPurchase { return status == .accepted && purchaseState != "placed" }
        return status == .accepted || status == .restaurantConfirmed
    }

    var driverAction: (OrderStatus, String)? {
        if usesCustomerHandoff, status == .restaurantConfirmed {
            guard !detailsNeedReview, placeChangePending != true, pendingReadyAt == nil else { return nil }
            return (.pickedUp, "Mark picked up")
        }
        return status.driverNext
    }
}

struct AttentionRow: Codable {
    var status: String
    var customerId: String
    var driverId: String
}

struct Place: Codable, Identifiable, Equatable {
    var placeId: String
    var name: String
    var address: String
    var lat: Double
    var lng: Double
    var rating: Double?
    var ratingCount: Int?
    var website: String?
    var mapsUrl: String?
    /// Places API (New) photo resource name. Not a public image URL and not stored as a licensed asset.
    var photoName: String?
    /// Additional Places photo resource names for the gallery. Not durable licensed assets.
    var photoNames: [String]? = nil
    var photoCredit: String?
    /// google, osm, or sample. Sample places are fictional offline listings.
    var contentSource: String?
    var category: String?
    var outsideCity: Bool?
    var id: String { placeId }
}

struct DetourEstimate: Codable, Equatable {
    var source: String
    var baseMinutes: Double
    var withMinutes: Double
    var toDropoffMinutes: Double
    var detourMinutes: Double
    var baseKm: Double
    var withKm: Double
    var basePath: [[Double]]
    var withPath: [[Double]]
}

struct AuthResponse: Codable {
    var token: String
    var user: SessionUser
    var profile: Profile
}

struct SessionResponse: Codable {
    var user: SessionUser
    var profile: Profile?
}

struct ProfileEnvelope: Codable { var profile: Profile? }
struct OrderEnvelope: Codable { var order: Order? }

struct OrderLine: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var quantity: Int
    var weightPounds: Double?
    var weightConfirmed: Bool
    var bulky: Bool
    var fragile: Bool
    var note: String?
}

struct InboxCount: Codable {
    var notices: Int
    var messages: Int
}

struct OrderMessage: Codable, Identifiable, Equatable {
    var id: String
    var orderId: String
    var senderId: String
    var body: String
    var createdAt: String
    var seenBy: [String]? = nil
}

struct MessageList: Codable { var messages: [OrderMessage] }

struct DemoActor: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var detail: String
}

struct DemoActorList: Codable { var actors: [DemoActor] }
struct PlaceSearchResponse: Codable { var source: String; var places: [Place] }
