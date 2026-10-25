import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var handle = ""
    @State private var server = ""
    @State private var busy = false
    @State private var saved = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Avatar(name: model.profile?.displayName)
                        VStack(alignment: .leading) {
                            Text(model.profile?.displayName ?? "").font(.headline)
                            Text(model.user?.email ?? "").foregroundStyle(Theme.muted)
                        }
                    }
                }
                Section("Profile") {
                    TextField("Display name", text: $name)
                    TextField("Payment handle", text: $handle)
                    if let error { ErrorBanner(message: error) }
                    if saved { Text("Saved").foregroundStyle(Theme.good) }
                    Button(busy ? "Saving…" : "Save profile") { save() }.disabled(busy)
                }
                Section("Server") {
                    TextField("Server address", text: $server)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Text("Accounts and orders live on this Howdy Haul server.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                Section {
                    Button("Sign out", role: .destructive) { Task { await model.signOut() } }
                }
                Section {
                    Text("Home Run coordinates deliveries only. Restaurant orders and delivery fees are paid outside the app.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
            .navigationTitle("Profile")
            .scrollContentBackground(.hidden)
            .background(Theme.cream)
            .onAppear {
                name = model.profile?.displayName ?? ""
                handle = model.profile?.paymentHandle ?? ""
                server = model.serverURL
            }
            .onChange(of: server) { _, value in model.serverURL = value }
        }
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Your name can't be empty."
            return
        }
        busy = true
        saved = false
        Task {
            defer { busy = false }
            do {
                let updated: Profile = try await model.client().store(
                    "profile",
                    method: "PATCH",
                    body: ProfilePatch(displayName: name.trimmingCharacters(in: .whitespaces), paymentHandle: handle.trimmingCharacters(in: .whitespaces).isEmpty ? nil : handle)
                )
                model.profile = updated
                saved = true
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
