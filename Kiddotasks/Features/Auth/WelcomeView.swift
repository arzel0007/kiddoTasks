import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showSignUp = false
    @State private var showSignIn = false
    @State private var showJoinWithCode = false

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
                    color: KiddotasksDesignTokens.Colors.primary
                ) { showSignIn = true }
                SecondaryButton(title: "Join existing family") { showJoinWithCode = true }
                SecondaryButton(title: "Create a new family") { showSignUp = true }
            } else {
                PrimaryButton(
                    title: "Create family",
                    color: KiddotasksDesignTokens.Colors.primary
                ) { showSignUp = true }
                SecondaryButton(title: "Join existing family") { showJoinWithCode = true }
                SecondaryButton(title: "I already have a family — sign in") { showSignIn = true }
            }

            Text(appState.isCloudEnabled
                 ? "Your family is saved securely in the cloud and stays in sync on every device."
                 : (appState.store.hasExistingAccount
                    ? "Sign in opens the family saved on this device. Connect Firebase for cross-device sync."
                    : "Data stays on this device until you connect Firebase."))
                .font(KiddotasksDesignTokens.Typography.captionSmall)
                .foregroundStyle(KiddotasksDesignTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, KiddotasksDesignTokens.Spacing.xxSmall)
        }
        .padding(KiddotasksDesignTokens.Spacing.xLarge)
        .kiddoPageBackground(KiddotasksDesignTokens.PageBackgrounds.welcome)
        .sheet(isPresented: $showSignUp) { SignUpView() }
        .sheet(isPresented: $showSignIn) { SignInView() }
        .sheet(isPresented: $showJoinWithCode) { JoinWithCodeView() }
    }
}

struct SignUpView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var familyName = ""
    @State private var parentName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPinAlert = false

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
                if appState.isLoading {
                    ToolbarItem(placement: .principal) {
                        ProgressView()
                    }
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
                        ) {
                            if appState.familyBootstrapPIN != nil {
                                showPinAlert = true
                            } else {
                                dismiss()
                            }
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || appState.isLoading)
                }
            }
            .alert("Your Kids Station PIN", isPresented: $showPinAlert) {
                Button("Got it") { dismiss() }
            } message: {
                Text("Shared family PIN: \(appState.familyBootstrapPIN ?? "")\nKids use it once to start a session on the shared iPad.")
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
                            Text(appState.isCloudEnabled
                                 ? "Sign in to open your family from the cloud."
                                 : "Sign in with the account saved on this device.")
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
                    Text(appState.isCloudEnabled
                         ? "Your account and family live in the cloud, so this family can be opened on any of your devices."
                         : "Right now this family is saved on this device. Connect Firebase to sync it everywhere.")
                        .font(KiddotasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                }
            }
            .navigationTitle("Sign in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if appState.isLoading {
                    ToolbarItem(placement: .principal) {
                        ProgressView()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sign in") {
                        appState.signIn(email: email, password: password) {
                            dismiss()
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || appState.isLoading)
                }
            }
        }
    }
}

/// Join an existing family using a shared family code.
struct JoinWithCodeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var familyCode = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        KiddotasksLogoMark(size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Join a family")
                                .font(KiddotasksDesignTokens.Typography.titleSmall)
                            Text("Enter the family code shared by the other parent.")
                                .font(KiddotasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section("Family code") {
                    TextField("KDO-XXXX", text: $familyCode)
                        .textInputAutocapitalization(.characters)
                }
                Section("Your account") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                }
                if let error = appState.authenticationError {
                    Text(error).foregroundStyle(KiddotasksDesignTokens.Colors.error)
                }
                Section {
                    Text("The family code was shown in the other parent's Family tab.")
                        .font(KiddotasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                }
            }
            .navigationTitle("Join family")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if appState.isLoading {
                    ToolbarItem(placement: .principal) {
                        ProgressView()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        appState.joinWithCode(
                            code: familyCode,
                            email: email,
                            password: password
                        ) {
                            dismiss()
                        }
                    }
                    .disabled(familyCode.isEmpty || email.isEmpty || password.isEmpty || appState.isLoading)
                }
            }
        }
    }
}
