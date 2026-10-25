import Foundation
import Observation

@Observable
final class AppModel {
    var token: String? {
        didSet {
            if let token { UserDefaults.standard.set(token, forKey: "token") }
            else { UserDefaults.standard.removeObject(forKey: "token") }
        }
    }
    var user: SessionUser?
    var profile: Profile?
    var restoring = true
    var restoreError: String?
    var noticeBadge = 0
    var ordersBadge = 0
    var repeatLines: [OrderLine] = []
    var requestedCustomerTab: String?
    var driveBadge = 0
    var side = AppSide.ordering
    var pickupCity: String
    var pickupCityConfirmed: Bool
    /// Transient. Only buttons and an action that needs a city set this.
    var cityPickerOpen = false
    var stagedFavorite: SavedPlace?
    var driveRootTick = 0
    var runnerArea = ""
    var runnerAreaSource = ""
    var runnerLat: Double?
    var runnerLng: Double?

    var runnerOrigin: RequestRanking.Origin? {
        guard let runnerLat, let runnerLng, !runnerAreaSource.isEmpty else { return nil }
        return RequestRanking.Origin(lat: runnerLat, lng: runnerLng, label: runnerArea, source: runnerAreaSource)
    }

    func setManualArea(_ city: String) {
        guard let place = Places.city(named: city) else { return }
        runnerArea = place.name
        runnerAreaSource = "manual"
        runnerLat = place.lat
        runnerLng = place.lng
        UserDefaults.standard.set(place.name, forKey: "homerun.runnerArea")
        UserDefaults.standard.set("manual", forKey: "homerun.runnerAreaSource")
    }

    func setDeviceArea(lat: Double, lng: Double, label: String) {
        runnerArea = label
        runnerAreaSource = "device"
        runnerLat = lat
        runnerLng = lng
        UserDefaults.standard.set(label, forKey: "homerun.runnerArea")
        UserDefaults.standard.set("device", forKey: "homerun.runnerAreaSource")
    }

    enum AppSide: Equatable { case ordering, driving }

    init() {
        token = UserDefaults.standard.string(forKey: "token")
        let stored = UserDefaults.standard.string(forKey: "homerun.pickupCity")
        pickupCity = Places.city(named: stored ?? "")?.name ?? Places.origins[0].name
        pickupCityConfirmed = UserDefaults.standard.bool(forKey: "homerun.pickupCityConfirmed")
        runnerArea = UserDefaults.standard.string(forKey: "homerun.runnerArea") ?? ""
        runnerAreaSource = UserDefaults.standard.string(forKey: "homerun.runnerAreaSource") ?? ""
        if runnerAreaSource == "manual", let place = Places.city(named: runnerArea) {
            runnerLat = place.lat
            runnerLng = place.lng
        }
    }

    func confirmPickupCity(_ name: String) {
        let resolved = Places.city(named: name)
        guard let resolved else { return }
        pickupCity = resolved.name
        pickupCityConfirmed = true
        UserDefaults.standard.set(resolved.name, forKey: "homerun.pickupCity")
        UserDefaults.standard.set(true, forKey: "homerun.pickupCityConfirmed")
    }

    func stageRepeat(_ lines: [OrderLine]) {
        repeatLines = lines
        side = .ordering
        requestedCustomerTab = "discover"
    }

    func takeRepeatLines() -> [OrderLine] {
        let lines = repeatLines
        repeatLines = []
        return lines
    }

    func client() throws -> APIClient {
        APIClient(token: token)
    }

    func restore() async {
        restoring = true
        defer { restoring = false }
        guard token != nil else { return }
        do {
            let session: SessionResume = try await client().store("session")
            user = session.user
            profile = session.profile
            restoreError = nil
            alignSide()
            await refreshBadges()
        } catch {
            signOutLocal()
        }
    }

    func enterDemo() async throws {
        try await signIn(email: "anishkoduri@tamu.edu", password: "demo")
    }

    func signIn(email: String, password: String) async throws {
        let response: AuthResponse = try await client().store("signin", method: "POST", body: Credentials(email: email, password: password, displayName: nil, intent: nil))
        apply(response)
    }

    func signUp(name: String, email: String, password: String, use: AccountUse) async throws {
        let response: AuthResponse = try await client().store("signup", method: "POST", body: Credentials(email: email, password: password, displayName: name, intent: use.rawValue))
        apply(response)
    }

    func signOut() async {
        if token != nil, let client = try? client() {
            let _: Okay = (try? await client.store("signout", method: "POST")) ?? Okay(ok: true)
        }
        signOutLocal()
    }

    func refreshBadges() async {
        guard token != nil, let client = try? client() else { return }
        guard let rows: [AttentionRow] = try? await client.store("attention"), let user else { return }
        ordersBadge = rows.filter { $0.customerId == user.id && $0.status == "accepted" }.count
        driveBadge = rows.filter { $0.driverId == user.id && $0.status == "requested" }.count
        if let count: InboxCount = try? await client.store("inbox-count") {
            noticeBadge = count.notices + count.messages
        }
    }

    private func apply(_ response: AuthResponse) {
        token = response.token
        user = response.user
        profile = response.profile
        restoreError = nil
        alignSide()
        Task { await refreshBadges() }
    }

    func useDemoActor(_ id: String) async throws {
        let response: AuthResponse = try await client().store("demo-actor", method: "POST", body: DemoActorPick(id: id))
        apply(response)
    }

    private func alignSide() {
        if profile?.use == .deliver { side = .driving }
        if profile?.use == .order { side = .ordering }
    }

    private func signOutLocal() {
        token = nil
        user = nil
        profile = nil
        ordersBadge = 0
        driveBadge = 0
        noticeBadge = 0
    }
}

private struct Credentials: Encodable {
    var email: String
    var password: String
    var displayName: String?
    var intent: String?
}

private struct Okay: Decodable { var ok: Bool }

private struct SessionResume: Decodable {
    var user: SessionUser
    var profile: Profile
}
