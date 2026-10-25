import Foundation
import Observation

@Observable
final class AppModel {
    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }
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

    init() {
        serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://127.0.0.1:5173"
        token = UserDefaults.standard.string(forKey: "token")
    }

    func client() throws -> APIClient {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: trimmed), url.scheme == "http" || url.scheme == "https" else {
            throw APIError(message: "Enter a server address like http://127.0.0.1:5173.")
        }
        return APIClient(baseURL: url, token: token)
    }

    func restore() async {
        restoring = true
        defer { restoring = false }
        guard token != nil else {
            user = nil
            profile = nil
            return
        }
        do {
            let session: SessionResponse = try await client().store("session")
            user = session.user
            profile = session.profile
            restoreError = session.profile == nil ? "Your profile couldn't be loaded." : nil
            await refreshBadges()
        } catch let error as APIError where error.code == "unauthenticated" {
            signOutLocal()
        } catch {
            restoreError = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async throws {
        let response: AuthResponse = try await client().store("signin", method: "POST", body: Credentials(email: email, password: password, displayName: nil))
        apply(response)
    }

    func signUp(name: String, email: String, password: String) async throws {
        let response: AuthResponse = try await client().store("signup", method: "POST", body: Credentials(email: email, password: password, displayName: name))
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
        Task { await refreshBadges() }
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
}

private struct Okay: Decodable { var ok: Bool }
