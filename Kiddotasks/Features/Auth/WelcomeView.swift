import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showSignUp = false
    @State private var showSignIn = false
    @State private var showJoinWithCode = false
    @State private var showKidsPIN = false

    var body: some View {
        VStack(spacing: KiddoTasksDesignTokens.Spacing.medium) {
            Spacer()

            KiddoTasksLogoMark(size: 108)
                .padding(.bottom, KiddoTasksDesignTokens.Spacing.small)

            Text("KiddoTasks")
                .font(KiddoTasksDesignTokens.Typography.displayLarge)
            Text("Missions for kids. Control for parents.")
                .font(KiddoTasksDesignTokens.Typography.bodyLarge)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            if appState.store.hasExistingAccount {
                PrimaryButton(
                    title: "Sign in",
                    color: KiddoTasksDesignTokens.Colors.primary
                ) { showSignIn = true }
                SecondaryButton(title: "Kids Station (PIN)") { showKidsPIN = true }
                SecondaryButton(title: "Join existing family") { showJoinWithCode = true }
                SecondaryButton(title: "Create a new family") { showSignUp = true }
            } else {
                PrimaryButton(
                    title: "Create family",
                    color: KiddoTasksDesignTokens.Colors.primary
                ) { showSignUp = true }
                SecondaryButton(title: "Kids Station (PIN)") { showKidsPIN = true }
                SecondaryButton(title: "Join existing family") { showJoinWithCode = true }
                SecondaryButton(title: "I already have a family — sign in") { showSignIn = true }
            }

            Text(appState.isCloudEnabled
                 ? "Your family is saved securely in the cloud and stays in sync on every device."
                 : (appState.store.hasExistingAccount
                    ? "Sign in opens the family saved on this device. Connect Firebase for cross-device sync."
                    : "Data stays on this device until you connect Firebase."))
                .font(KiddoTasksDesignTokens.Typography.captionSmall)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, KiddoTasksDesignTokens.Spacing.xxSmall)
        }
        .padding(KiddoTasksDesignTokens.Spacing.xLarge)
        .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.welcome)
        .sheet(isPresented: $showSignUp) { SignUpView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible) }
        .sheet(isPresented: $showSignIn) { SignInView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible) }
        .sheet(isPresented: $showJoinWithCode) { JoinWithCodeView() }
        .sheet(isPresented: $showKidsPIN) {
            KidsPINUnlockView()
                .presentationDetents([.medium, .large])
        }
        .onChange(of: showSignUp) { _, isShowing in
            if isShowing { appState.clearAuthMessages() }
        }
        .onChange(of: showSignIn) { _, isShowing in
            if isShowing { appState.clearAuthMessages() }
        }
        .onChange(of: showJoinWithCode) { _, isShowing in
            if isShowing { appState.clearAuthMessages() }
        }
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
            ScrollView {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.medium) {
                    HStack(spacing: 12) {
                        KiddoTasksLogoMark(size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("New family")
                                .font(KiddoTasksDesignTokens.Typography.titleSmall)
                            Text("Set up chores and rewards in about two minutes.")
                                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                    KiddoFormSection(title: "Family", icon: "house.fill") {
                        KiddoTextField(label: "Family name", placeholder: "Our family", text: $familyName)
                        KiddoTextField(label: "Your name", placeholder: "Parent", text: $parentName)
                    }

                    KiddoFormSection(title: "Account", icon: "person.crop.circle") {
                        KiddoTextField(
                            label: "Email",
                            placeholder: "you@example.com",
                            text: $email,
                            keyboard: .emailAddress,
                            autocapitalization: .never
                        )
                        KiddoTextField(
                            label: "Password",
                            placeholder: "6+ characters",
                            text: $password,
                            isSecure: true
                        )
                    }

                    if let error = appState.authenticationError {
                        Text(error)
                            .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    PrimaryButton(title: appState.isLoading ? "Creating…" : "Create family") {
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
                    .opacity(appState.isLoading ? 0.7 : 1)
                }
                .padding(KiddoTasksDesignTokens.Spacing.medium)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.parentPage)
            .navigationTitle("New family")
            .onAppear { appState.clearAuthMessages() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appState.clearAuthMessages()
                        dismiss()
                    }
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
            ScrollView {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.medium) {
                    HStack(spacing: 12) {
                        KiddoTasksLogoMark(size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Welcome back")
                                .font(KiddoTasksDesignTokens.Typography.titleSmall)
                            Text(appState.isCloudEnabled
                                 ? "Sign in to open your family from the cloud."
                                 : "Sign in with the account saved on this device.")
                                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    KiddoFormSection(title: "Account", icon: "person.crop.circle") {
                        KiddoTextField(
                            label: "Email",
                            placeholder: "you@example.com",
                            text: $email,
                            keyboard: .emailAddress,
                            autocapitalization: .never
                        )
                        KiddoTextField(label: "Password", placeholder: "Your password", text: $password, isSecure: true)
                        Button("Forgot password?") {
                            appState.sendPasswordReset(email: email)
                        }
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                        .disabled(email.isEmpty)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let error = appState.authenticationError {
                        Text(error)
                            .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let successMessage = appState.successMessage {
                        Text(successMessage)
                            .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.success)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PrimaryButton(title: appState.isLoading ? "Signing in…" : "Sign in") {
                        Haptic.medium()
                        appState.signIn(email: email, password: password) {
                            dismiss()
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || appState.isLoading)
                    .opacity(appState.isLoading ? 0.7 : 1)

                    Text(appState.isCloudEnabled
                         ? "Your account and family live in the cloud, so this family can be opened on any of your devices."
                         : "Right now this family is saved on this device. Connect Firebase to sync it everywhere.")
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(KiddoTasksDesignTokens.Spacing.medium)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.parentPage)
            .navigationTitle("Sign in")
            .onAppear { appState.clearAuthMessages() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appState.clearAuthMessages()
                        dismiss()
                    }
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
            ScrollView {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.medium) {
                    HStack(spacing: 12) {
                        KiddoTasksLogoMark(size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Join a family")
                                .font(KiddoTasksDesignTokens.Typography.titleSmall)
                            Text("Enter the family code shared by the other parent.")
                                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    KiddoFormSection(title: "Family code", icon: "qrcode") {
                        KiddoTextField(
                            label: "Code",
                            placeholder: "KDO-XXXX",
                            text: $familyCode,
                            autocapitalization: .characters
                        )
                        Text("Shown in the other parent's Family tab.")
                            .font(KiddoTasksDesignTokens.Typography.captionSmall)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                    }

                    KiddoFormSection(title: "Your account", icon: "person.crop.circle") {
                        KiddoTextField(
                            label: "Email",
                            placeholder: "you@example.com",
                            text: $email,
                            keyboard: .emailAddress,
                            autocapitalization: .never
                        )
                        KiddoTextField(label: "Password", placeholder: "Create a password", text: $password, isSecure: true)
                    }

                    if let error = appState.authenticationError {
                        Text(error)
                            .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PrimaryButton(title: appState.isLoading ? "Joining…" : "Join family") {
                        appState.joinWithCode(
                            code: familyCode,
                            email: email,
                            password: password
                        ) {
                            dismiss()
                        }
                    }
                    .disabled(familyCode.isEmpty || email.isEmpty || password.isEmpty || appState.isLoading)
                    .opacity(appState.isLoading ? 0.7 : 1)
                }
                .padding(KiddoTasksDesignTokens.Spacing.medium)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.parentPage)
            .navigationTitle("Join family")
            .onAppear { appState.clearAuthMessages() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appState.clearAuthMessages()
                        dismiss()
                    }
                }
            }
        }
    }
}
