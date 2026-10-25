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
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Home Run")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text(mode == .signIn ? "Welcome back" : "Join the trip")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.maroon)
                .padding(.horizontal, -24)
                .padding(.top, -24)

                Text("Your favorites.\nOn their way home.")
                    .font(Theme.display(.largeTitle))
                    .foregroundStyle(Theme.ink)
                Text("Students already driving to College Station can bring food or groceries, or you can bring some on your own drive.")
                    .foregroundStyle(Theme.muted)

                if mode == .signUp {
                    field("Your name", text: $name)
                    Text("What do you want to do?").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                    ForEach(AccountUse.allCases) { option in
                        Button {
                            use = option
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: use == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(Theme.maroon)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title).fontWeight(.semibold).foregroundStyle(Theme.ink)
                                    Text(option.detail).font(.caption).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                field("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                SecureField("Password", text: $password)
                    .padding(12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                if let error { ErrorBanner(message: error) }
                PrimaryButton(title: mode == .signIn ? "Sign in" : "Create account", busy: busy) { submit() }
                Button(mode == .signIn ? "Create an account" : "Sign in") {
                    mode = mode == .signIn ? .signUp : .signIn
                    error = nil
                }
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                Text("Student-run project. Not affiliated with any university. Accounts stay on this phone.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
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
