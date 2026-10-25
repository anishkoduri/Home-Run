import SwiftUI

struct AuthView: View {
    @Environment(AppModel.self) private var model
    @State private var mode = Mode.signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var server = ""
    @State private var busy = false
    @State private var error: String?

    enum Mode { case signIn, signUp }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "car.fill")
                        .frame(width: 34, height: 34)
                        .foregroundStyle(Theme.gold)
                        .background(Theme.maroon)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("Home Run").font(.title3.weight(.bold)).foregroundStyle(Theme.maroon)
                }
                Text(mode == .signIn ? "Welcome back" : "Join Home Run")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.maroon)
                Text("Get food from back home brought by students already driving to College Station, or bring some yourself.")
                    .foregroundStyle(Theme.muted)

                if mode == .signUp {
                    field("Your name", text: $name)
                }
                field("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                SecureField("Password", text: $password)
                    .padding(12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                field("Server", text: $server)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                Text("The Howdy Haul dev server. The iPhone simulator can use http://127.0.0.1:5173.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                if let error { ErrorBanner(message: error) }
                PrimaryButton(title: mode == .signIn ? "Sign in" : "Create account", busy: busy) { submit() }
                Button(mode == .signIn ? "Create an account" : "Sign in") {
                    mode = mode == .signIn ? .signUp : .signIn
                    error = nil
                }
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                Text("Student-run project. Not affiliated with any university. Accounts stay on the server you enter above.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .onAppear { server = model.serverURL }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
            TextField(title, text: text)
                .padding(12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func submit() {
        error = nil
        if mode == .signUp && name.trimmingCharacters(in: .whitespaces).count < 2 {
            error = "Add the name other students will see."
            return
        }
        if password.count < 8 {
            error = "Use a password with at least 8 characters."
            return
        }
        model.serverURL = server.trimmingCharacters(in: .whitespacesAndNewlines)
        busy = true
        Task {
            defer { busy = false }
            do {
                if mode == .signIn {
                    try await model.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
                } else {
                    try await model.signUp(name: name.trimmingCharacters(in: .whitespaces), email: email.trimmingCharacters(in: .whitespaces), password: password)
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
