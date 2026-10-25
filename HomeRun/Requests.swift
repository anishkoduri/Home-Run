import Foundation

struct NewTripBody: Encodable {
    struct Draft: Encodable {
        var originCity: String
        var originLat: Double
        var originLng: Double
        var destinationCity: String
        var destinationLat: Double
        var destinationLng: Double
        var departureAt: String
        var maxOrders: Int
        var notes: String?
        var status: String? = nil
    }

    struct Stop: Encodable {
        var placeId: String?
        var restaurantName: String
        var address: String?
        var lat: Double
        var lng: Double
    }

    var trip: Draft
    var stops: [Stop]
}

struct NewOrderBody: Encodable {
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
    var extraMeters: Double?
    var extraSeconds: Double?
    var weightPounds: Double?
    var weightConfirmed: Bool?
    var bulky: Bool?
    var itemSummary: String?
    var pickupReference: String?
    var lines: [OrderLine]?
    var operationKey: String? = nil
    var requestText: String? = nil
    var merchandiseCents: Int? = nil
    var substitution: String? = nil
    var personalItem: Bool? = nil
    var screenshotBase64: String? = nil
    var pickupKind: String? = nil
    var contactLabel: String? = nil
    var accessInstructions: String? = nil
    var pickupWindow: String? = nil
    var itemQuantity: String? = nil
    var fragile: Bool? = nil
    var alreadyOrdered: Bool? = nil
    var pickupName: String? = nil
    var restaurantOrderNumber: String? = nil
    var referenceMissing: Bool? = nil
    var pickupReadyAt: String? = nil
    var pickupCode: String? = nil
    var pickupInstructions: String? = nil
    var readyConfirmed: Bool? = nil
}

struct HandoffSubmit: Encodable {
    var handoffSubmit: Bool = true
    var requestText: String
    var pickupName: String?
    var restaurantOrderNumber: String?
    var referenceMissing: Bool?
    var pickupWindow: String?
    var pickupReadyAt: String?
    var pickupCode: String?
    var pickupInstructions: String?
    var readyConfirmed: Bool?
    var contactLabel: String?
    var accessInstructions: String?
    var screenshotBase64: String?
    var removeScreenshot: Bool?
    var branchNote: String?
}

struct DetailsDecision: Encodable { var detailsDecision: String }
struct WindowDecision: Encodable { var windowDecision: String }
struct PlaceDecision: Encodable { var placeDecision: String }
struct CollectionPatch: Encodable { var status: String; var collectionConfirmed: Bool }

struct PurchasePatch: Encodable {
    var purchaseActualCents: Int
    var purchaseReference: String?
}

struct RevisionDecision: Encodable {
    var revisionDecision: String
}

struct DeliveryPatch: Encodable {
    var status: String
    var pin: String?
}

struct MessageDraft: Encodable {
    var orderId: String
    var body: String
}

struct DemoActorPick: Encodable {
    var id: String
}

struct StatusPatch: Encodable { var status: String }

struct PickupPatch: Encodable {
    var pickupName: String
    var restaurantOrderNumber: String?
    var pickupReadyAt: String
    var pickupInstructions: String?
    var status: String?
}

struct ProfilePatch: Encodable {
    var displayName: String
    var paymentHandle: String?
}

struct DeclinePatch: Encodable {
    var status: String
    var declineReason: String
}

struct CounterPatch: Encodable {
    var counterCents: Int
    var counterReason: String
}

struct CounterDecision: Encodable {
    var counterDecision: String
}

struct SavedRequestDraft: Encodable {
    var city: String
    var placeName: String?
}

struct SupportDraft: Encodable {
    var orderId: String?
    var category: String
    var details: String
}

struct NoticeRead: Encodable {
    var id: String?
    var all: Bool?
}

struct TripStatusPatch: Encodable { var status: String }

struct RepeatTrip: Encodable {
    var tripId: String
    var cadence: String
}
