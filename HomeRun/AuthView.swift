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
    @State private var revealPassword = false
    @State private var agreed = false
    @State private var legal: LegalPage?

    enum Mode { case signIn, signUp }
    enum LegalPage: String, Identifiable { case terms, privacy; var id: String { rawValue } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Wordmark(ink: .white)
                        Text("By Aggies, for Aggies.")
                            .font(Theme.text(.caption, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .accessibilityIdentifier("slogan")
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
                                    Text(option.title).font(Theme.text(.body, weight: .semibold)).foregroundStyle(Theme.ink)
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
                field("Email", text: $email, keyboard: .emailAddress)
                    .textInputAutocapitalization(.never)
                RequiredLabel(title: "Password", required: true)
                HStack(spacing: 8) {
                    Group {
                        if revealPassword {
                            EntryField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                                .font(Theme.text(.body))
                        }
                    }
                    .textContentType(mode == .signIn ? .password : .newPassword)
                    Button(revealPassword ? "Hide" : "Show") { revealPassword.toggle() }
                        .font(Theme.text(.caption, weight: .bold))
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel(revealPassword ? "Hide password" : "Show password")
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .sketchPanel()
                if mode == .signUp {
                    Toggle(isOn: $agreed) {
                        Text("I agree to the terms and privacy note")
                    }
                    .font(Theme.text(.body))
                    HStack(spacing: 16) {
                        Button("Terms") { legal = .terms }.font(Theme.text(.caption, weight: .semibold))
                        Button("Privacy") { legal = .privacy }.font(Theme.text(.caption, weight: .semibold))
                    }
                    Text("Creating an account stays on this phone. No email is sent and no bank or card details are collected.")
                        .font(Theme.text(.caption))
                        .foregroundStyle(Theme.muted)
                }
                if let error { ErrorBanner(message: error) }
                PrimaryButton(title: mode == .signIn ? "Log in" : "Create account", busy: busy) { submit() }
                Button(mode == .signIn ? "Create an account" : "Sign in") {
                    mode = mode == .signIn ? .signUp : .signIn
                    error = nil
                }
                .font(Theme.text(.body, weight: .semibold))
                .frame(maxWidth: .infinity)
                if mode == .signIn {
                    Button("Forgot password") { error = "No email was sent. This demo keeps the password on this phone." }
                        .font(Theme.text(.caption, weight: .semibold))
                    Button("Explore the demo") { enterDemo() }
                        .font(Theme.text(.body, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("demo-entry")
                    Text("Sample sign-in on this phone. It does not create an external account or send email.")
                        .font(Theme.text(.caption))
                        .foregroundStyle(Theme.muted)
                }
                Text("Student-run project. Not affiliated with any university. Accounts stay on this phone.")
                    .font(Theme.text(.caption2))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .homeRunPage(road: false)
        .background(Theme.cream.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $legal) { page in
            NavigationStack {
                ScrollView {
                    Text(page == .terms ? LegalCopy.terms : LegalCopy.privacy)
                        .font(Theme.text(.footnote))
                        .padding(20)
                }
                .homeRunPage(road: false)
                .navigationTitle(page == .terms ? "Terms" : "Privacy")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { legal = nil } } }
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RequiredLabel(title: title, required: true)
            EntryField(title, text: text, keyboard: keyboard)
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
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        if trimmedEmail.isEmpty || (mode == .signUp && (!trimmedEmail.contains("@") || trimmedEmail.contains(" "))) {
            error = "Enter an email address."
            return
        }
        if mode == .signUp && password.count < 8 {
            error = "Use a password with at least 8 characters."
            return
        }
        if password.isEmpty {
            error = "Enter a password."
            return
        }
        if mode == .signUp && !agreed {
            error = "Agree to the terms to create an account."
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
                    if let user = model.user { DemoTerms.accept(userId: user.id) }
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func enterDemo() {
        error = nil
        busy = true
        Task {
            defer { busy = false }
            do { try await model.enterDemo() }
            catch { self.error = "The sample sign-in stayed on this phone and did not go through. \(error.localizedDescription)" }
        }
    }
}
