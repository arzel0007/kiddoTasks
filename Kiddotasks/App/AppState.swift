import Foundation
import Observation
import SwiftUI

/// Root application state. Uses the local family store so the app is fully usable
/// on device without Firebase. Firebase repositories remain for a later cloud cutover.
@Observable
final class AppState {
    let store = LocalFamilyDataStore()

    var currentChildProfile: Child?
    var interfaceOverride: InterfaceOverride = .automatic
    var authenticationError: String?
    var isLoading: Bool = false
    var errorMessage: String?

    enum InterfaceOverride: String, CaseIterable, Identifiable {
        case automatic
        case parent
        case kids

        var id: String { rawValue }

        var label: String {
            switch self {
            case .automatic: return "Automatic"
            case .parent: return "Parent Center"
            case .kids: return "Kids Station"
            }
        }
    }

    var isAuthenticated: Bool { store.isAuthenticated }
    var currentFamily: Family? { store.family }
    var currentParent: Parent? { store.parent }
    var familyChildren: [Child] { store.children }

    var isIPad: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    var applicationMode: ApplicationMode {
        if !isAuthenticated {
            return .login
        }
        switch interfaceOverride {
        case .parent:
            return .parentControl
        case .kids:
            return currentChildProfile == nil ? .kidsSelection : .kidsStation
        case .automatic:
            if isIPad {
                return currentChildProfile == nil ? .kidsSelection : .kidsStation
            }
            return .parentControl
        }
    }

    func selectChildProfile(_ child: Child) {
        currentChildProfile = child
    }

    func clearChildProfile() {
        currentChildProfile = nil
    }

    func signUp(familyName: String, parentName: String, email: String, password: String) {
        authenticationError = nil
        do {
            try store.signUp(
                familyName: familyName,
                parentName: parentName,
                email: email,
                password: password
            )
        } catch {
            authenticationError = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) {
        authenticationError = nil
        do {
            try store.signIn(email: email, password: password)
        } catch {
            authenticationError = error.localizedDescription
        }
    }

    func signOut() {
        currentChildProfile = nil
        interfaceOverride = .automatic
        store.signOut()
    }

    func child(id: String) -> Child? {
        store.children.first { $0.id == id }
    }

    func task(id: String) -> KiddoTask? {
        store.tasks.first { $0.id == id }
    }

    func reward(id: String) -> Reward? {
        store.rewards.first { $0.id == id }
    }

    func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    func clearError() {
        errorMessage = nil
    }
}

enum ApplicationMode {
    case login
    case parentControl
    case kidsSelection
    case kidsStation
}
