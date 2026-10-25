import SwiftUI

struct AuthView: View {
    @Environment(AppModel.self) private var model
    @State private var mode = Mode.signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var use = AccountUse.both
    @State private var busy = false
    @State private var error: String?

    enum Mode { case signIn, signUp }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Home Run")
                            .font(Theme.display(.title2))
                            .foregroundStyle(.white)
                        Text(mode == .signIn ? "Sign in" : "Create an account")
                            .font(Theme.text(.subheadline))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.maroon.ignoresSafeArea(edges: .top))
                .padding(.horizontal, -24)
                .padding(.top, -24)

                Text("Bring something home.")
                    .font(Theme.display(.title2))
                    .foregroundStyle(Theme.ink)
                Text("Food runs to College Station.")
                    .font(Theme.text(.subheadline))
                    .foregroundStyle(Theme.muted)

                if mode == .signUp {
                    field("Your name", text: $name)
                    Text("What do you want to do?").font(Theme.text(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                    ForEach(AccountUse.allCases) { option in
                        Button {
                            use = option
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: use == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(Theme.maroon)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title).fontWeight(.semibold).foregroundStyle(Theme.ink)
                                    Text(option.detail).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .sketchPanel(ink: use == option ? Theme.maroon : Theme.ink.opacity(0.28))
                        }
                        .buttonStyle(.plain)
                    }
                }
                field("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                SecureField("Password", text: $password)
                    .padding(12)
                    .frame(minHeight: 44)
                    .sketchPanel()
                if let error { ErrorBanner(message: error) }
                PrimaryButton(title: mode == .signIn ? "Sign in" : "Create account", busy: busy) { submit() }
                Button(mode == .signIn ? "Create an account" : "Sign in") {
                    mode = mode == .signIn ? .signUp : .signIn
                    error = nil
                }
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                Text("Student-run project. Not affiliated with any university. Accounts stay on this phone.")
                    .font(Theme.text(.caption2))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .homeRunPage(road: false)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Theme.text(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
            TextField(title, text: text)
                .padding(12)
                .frame(minHeight: 44)
                .sketchPanel()
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
        busy = true
        Task {
            defer { busy = false }
            do {
                if mode == .signIn {
                    try await model.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
                } else {
                    try await model.signUp(name: name.trimmingCharacters(in: .whitespaces), email: email.trimmingCharacters(in: .whitespaces), password: password, use: use)
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
