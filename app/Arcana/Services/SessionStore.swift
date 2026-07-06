import Foundation
import AuthenticationServices
import Supabase

/// Authentication state. In demo mode (no Supabase credentials) the app skips
/// sign-in entirely and runs on the seeded local store.
@MainActor
final class SessionStore: ObservableObject {

    enum State: Equatable {
        case loading
        case signedOut
        case signedIn
        case demo
    }

    @Published private(set) var state: State = .loading
    @Published var errorMessage: String?

    private let client = SupabaseService.client

    init() {
        guard let client else {
            state = .demo
            return
        }
        Task {
            if (try? await client.auth.session) != nil {
                state = .signedIn
            } else {
                state = .signedOut
            }
        }
    }

    var userEmail: String? {
        guard let client else { return nil }
        return client.auth.currentUser?.email
    }

    // MARK: Sign in with Apple

    func signInWithApple(result: Result<ASAuthorization, Error>) async {
        guard let client else { return }
        do {
            guard case .success(let auth) = result,
                  let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8)
            else {
                if case .failure(let error) = result { throw error }
                return
            }
            try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )
            state = .signedIn
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Email

    func signIn(email: String, password: String) async {
        guard let client else { return }
        do {
            try await client.auth.signIn(email: email, password: password)
            state = .signedIn
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        guard let client else { return }
        do {
            try await client.auth.signUp(email: email, password: password)
            state = .signedIn
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        guard let client else { return }
        try? await client.auth.signOut()
        state = .signedOut
    }
}
