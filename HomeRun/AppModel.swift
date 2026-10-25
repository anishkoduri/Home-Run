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
    var ordersBadge = 0
    var driveBadge = 0
    var side = AppSide.ordering

    enum AppSide: Equatable { case ordering, driving }

    init() {
        token = UserDefaults.standard.string(forKey: "token")
    }

    func client() throws -> APIClient {
        APIClient(token: token)
    }

    func restore() async {
        restoring = true
        defer { restoring = false }
        signOutLocal()
        await signInDemo()
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
    }

    private func apply(_ response: AuthResponse) {
        token = response.token
        user = response.user
        profile = response.profile
        restoreError = nil
        alignSide()
        Task { await refreshBadges() }
    }

    private func signInDemo() async {
        do {
            try await signIn(email: "1", password: "1")
        } catch {
            restoreError = error.localizedDescription
        }
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
    }
}

private struct Credentials: Encodable {
    var email: String
    var password: String
    var displayName: String?
    var intent: String?
}

private struct Okay: Decodable { var ok: Bool }
