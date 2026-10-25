import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var handle = ""
    @State private var busy = false
    @State private var saved = false
    @State private var error: String?
    @State private var actors: [DemoActor] = []
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                PageHeader(title: "Profile")
                    .padding(.horizontal, -20)
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Avatar(name: model.profile?.displayName)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Format.personalName(model.profile?.displayName) ?? "Add your name").font(Theme.section(.headline))
                            Text(model.user?.email ?? "").font(Theme.text(.subheadline)).foregroundStyle(Theme.muted)
                            Text(model.profile?.use.title ?? "").font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.maroon)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sketchPanel()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your details").font(Theme.section())
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("About").font(Theme.section())
                        Text("Home Run").font(Theme.brand(.title3))
                        Text("By Aggies, for Aggies.")
                            .font(Theme.text(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.maroon)
                        Text("Demo • sample data • no real charges")
                            .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                    }
                    .padding(16)
                    .sketchPanel()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Demo tools").font(Theme.section())
                        NavigationLink("Notifications") { InboxView() }
                        NavigationLink("Saved requests") { SavedRequestsView() }
                        NavigationLink("Saved places") { SavedPlacesView() }
                        NavigationLink("Support") { SupportDeskView() }
                        NavigationLink("FAQ") { FAQView() }
                        NavigationLink("Demo controls") { DemoControlView() }
                    }
                    .font(Theme.text(.body, weight: .semibold))
                    .padding(16)
                    .sketchPanel()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Demo people").font(Theme.section())
                        ForEach(actors) { actor in
                            Button {
                                Task {
                                    do { try await model.useDemoActor(actor.id) }
                                    catch { self.error = error.localizedDescription }
                                }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(actor.name).font(Theme.text(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                                    Text(actor.detail).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("demo-actor-\(actor.id)")
                        }
                        Button("Advance demo clock 1 day") { DemoClock.advance(by: 86_400) }
                            .font(Theme.text(.caption, weight: .semibold))
                        Toggle("In-app notifications", isOn: Binding(
                            get: { model.profile?.notify != false },
                            set: { value in Task { await setNotify(value) } }
                        ))
                        Button("Remove demo profile") { confirmDelete = true }
                            .foregroundStyle(Theme.bad)
                    }
                    .padding(16)
                    .sketchPanel()

                    #if DEBUG
                    Text(GoogleCredentials.developerStatus)
                        .font(Theme.text(.caption))
                        .foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("google-credential-status")
                    #endif
                    Button("Sign out", role: .destructive) { Task { await model.signOut() } }
                        .font(Theme.text(.body, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                    Text("You pay the store yourself. Home Run's simulated charge is the delivery fee only. No card is charged.")
                        .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                }
                .padding(20)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(Theme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .homeRunPage(road: false)
            .background(Theme.cream.ignoresSafeArea())
            .onAppear {
                name = model.profile?.displayName ?? ""
                handle = model.profile?.paymentHandle ?? ""
            }
            .confirmationDialog("Remove this demo profile?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Remove demo profile", role: .destructive) { Task { await removeDemo() } }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("Active pickups must be finished first. History stays. A non-demo account is not removed.")
            }
            .task {
                let list: DemoActorList? = try? await model.client().store("demo-actors")
                actors = list?.actors ?? []
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

    private func setNotify(_ value: Bool) async {
        struct Body: Encodable { var notify: Bool }
        if let updated: Profile = try? await model.client().store("preferences", method: "PATCH", body: Body(notify: value)) {
            model.profile = updated
        }
    }

    private func removeDemo() async {
        do {
            let _: OkayBody = try await model.client().store("demo-delete", method: "POST")
            error = "This demo profile was removed from new use. Past records stay."
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct OkayBody: Decodable { var ok: Bool }
