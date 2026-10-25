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

struct TripStatusPatch: Encodable { var status: String }
