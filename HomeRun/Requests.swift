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
    var tripId: String
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
