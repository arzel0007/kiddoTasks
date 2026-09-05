import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showSignUp = false
    @State private var showSignIn = false

    var body: some View {
        VStack(spacing: KiddotasksDesignTokens.Spacing.medium) {
            Spacer()

            KiddotasksLogoMark(size: 108)
                .padding(.bottom, KiddotasksDesignTokens.Spacing.small)

            Text("Kiddotasks")
                .font(KiddotasksDesignTokens.Typography.displayLarge)
            Text("Missions for kids. Control for parents.")
                .font(KiddotasksDesignTokens.Typography.bodyLarge)
                .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            if appState.store.hasExistingAccount {
                PrimaryButton(
                    title: "Sign in",
                    gradient: KiddotasksDesignTokens.Gradients.hero
                ) { showSignIn = true }
                SecondaryButton(title: "Create a new family") { showSignUp = true }
            } else {
                PrimaryButton(
                    title: "Create family",
                    gradient: KiddotasksDesignTokens.Gradients.hero
                ) { showSignUp = true }
                SecondaryButton(title: "I already have a family — sign in") { showSignIn = true }
            }

            Text(appState.store.hasExistingAccount
                 ? "Sign in opens the family saved on this device. Cloud sync is coming soon."
                 : "Data stays on this device until you connect Firebase.")
                .font(KiddotasksDesignTokens.Typography.captionSmall)
                .foregroundStyle(KiddotasksDesignTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, KiddotasksDesignTokens.Spacing.xxSmall)
        }
        .padding(KiddotasksDesignTokens.Spacing.xLarge)
        .kiddoPageBackground(KiddotasksDesignTokens.Gradients.kidsPlayground)
        .sheet(isPresented: $showSignUp) { SignUpView() }
        .sheet(isPresented: $showSignIn) { SignInView() }
    }
}

struct SignUpView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var familyName = ""
    @State private var parentName = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        KiddotasksLogoMark(size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("New family")
                                .font(KiddotasksDesignTokens.Typography.titleSmall)
                            Text("Set up chores and rewards in about two minutes.")
                                .font(KiddotasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section("Family") {
                    TextField("Family name", text: $familyName)
                    TextField("Your name", text: $parentName)
                }
                Section("Account") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password (6+ characters)", text: $password)
                }
                if let error = appState.authenticationError {
                    Text(error).foregroundStyle(KiddotasksDesignTokens.Colors.error)
                }
            }
            .navigationTitle("New family")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard password.count >= 6 else {
                            appState.authenticationError = "Password must be at least 6 characters"
                            return
                        }
                        appState.signUp(
                            familyName: familyName.isEmpty ? "Our family" : familyName,
                            parentName: parentName.isEmpty ? "Parent" : parentName,
                            email: email,
                            password: password
                        )
                        if appState.authenticationError == nil {
                            dismiss()
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty)
                }
            }
        }
    }
}

struct SignInView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        KiddotasksLogoMark(size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Welcome back")
                                .font(KiddotasksDesignTokens.Typography.titleSmall)
                            Text("Sign in with the account saved on this device.")
                                .font(KiddotasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section("Account") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                }
                if let error = appState.authenticationError {
                    Text(error).foregroundStyle(KiddotasksDesignTokens.Colors.error)
                }
                Section {
                    Text("Using a new device? Connect Firebase in a future update to sync your family across phones and iPads.")
                        .font(KiddotasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                }
            }
            .navigationTitle("Sign in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sign in") {
                        appState.signIn(email: email, password: password)
                        if appState.authenticationError == nil {
                            dismiss()
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty)
                }
            }
        }
    }
}
