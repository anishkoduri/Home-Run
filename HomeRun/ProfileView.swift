import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var handle = ""
    @State private var busy = false
    @State private var saved = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Avatar(name: model.profile?.displayName)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Format.personalName(model.profile?.displayName) ?? "Add your name").font(Theme.display(.headline))
                            Text(model.user?.email ?? "").font(Theme.text(.subheadline)).foregroundStyle(Theme.muted)
                            Text(model.profile?.use.title ?? "").font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.maroon)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sketchPanel()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Profile").font(Theme.display(.headline))
                        TextField("Display name", text: $name)
                            .padding(12)
                            .frame(minHeight: 44)
                            .sketchPanel()
                            .accessibilityLabel("Display name")
                        TextField("Payment handle", text: $handle)
                            .padding(12)
                            .frame(minHeight: 44)
                            .sketchPanel()
                            .accessibilityLabel("Payment handle")
                        if let error { ErrorBanner(message: error) }
                        if saved { Text("Saved").font(Theme.text(.subheadline, weight: .semibold)).foregroundStyle(Theme.good) }
                        PrimaryButton(title: busy ? "Saving…" : "Save profile", busy: busy) { save() }
                    }
                    .padding(16)
                    .sketchPanel()

                    Button("Sign out", role: .destructive) { Task { await model.signOut() } }
                        .font(Theme.text(.body, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                    Text("Home Run coordinates deliveries only. Restaurant orders and delivery fees are paid outside the app.")
                        .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                }
                .padding(20)
            }
            .navigationTitle("Profile")
            .homeRunPage(road: false)
            .onAppear {
                name = model.profile?.displayName ?? ""
                handle = model.profile?.paymentHandle ?? ""
            }
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
