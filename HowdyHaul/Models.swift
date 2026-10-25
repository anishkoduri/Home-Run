import Foundation

enum OrderStatus: String, Codable, CaseIterable {
    case requested, accepted, restaurantConfirmed = "restaurant_confirmed"
    case pickedUp = "picked_up", onTheWay = "on_the_way", delivered, declined, cancelled

    var label: String {
        switch self {
        case .requested: return "Waiting for driver"
        case .accepted: return "Driver accepted"
        case .restaurantConfirmed: return "Restaurant order confirmed"
        case .pickedUp: return "Picked up"
        case .onTheWay: return "On the way"
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
    var isActiveDelivery: Bool { self == .accepted || self == .restaurantConfirmed || self == .pickedUp || self == .onTheWay }

    enum Tone { case pending, active, completed, closed }

    var driverNext: (OrderStatus, String)? {
        switch self {
        case .restaurantConfirmed: return (.pickedUp, "Mark picked up")
        case .pickedUp: return (.onTheWay, "Mark on the way")
        case .onTheWay: return (.delivered, "Mark delivered")
        default: return nil
        }
    }

    var customerCanCancel: Bool { self == .requested || self == .accepted || self == .restaurantConfirmed }
    var driverCanCancel: Bool { self == .accepted || self == .restaurantConfirmed }
}

struct SessionUser: Codable, Equatable {
    var id: String
    var email: String
}

struct Profile: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var avatarUrl: String?
    var paymentHandle: String?
    var createdAt: String?
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
struct PlaceSearchResponse: Codable { var source: String; var places: [Place] }
