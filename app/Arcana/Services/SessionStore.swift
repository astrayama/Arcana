import Foundation
import AuthenticationServices
#if canImport(Supabase)
import Supabase
#endif

/// Authentication state. In local mode (Supabase package not linked, or no
/// credentials) the app reports `.demo` and runs on the seeded local store.
/// The public API is identical in both modes so the UI compiles either way;
/// the Supabase-backed internals are guarded by `#if canImport(Supabase)`.
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

    #if canImport(Supabase)
    private let client = SupabaseService.client
    #endif

    init() {
        #if canImport(Supabase)
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
        #else
        state = .demo
        #endif
    }

    var userEmail: String? {
        #if canImport(Supabase)
        return client?.auth.currentUser?.email
        #else
        return nil
        #endif
    }

    // MARK: Sign in with Apple

    func signInWithApple(result: Result<ASAuthorization, Error>) async {
        #if canImport(Supabase)
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
        #endif
    }

    // MARK: Email

    func signIn(email: String, password: String) async {
        #if canImport(Supabase)
        guard let client else { return }
        do {
            try await client.auth.signIn(email: email, password: password)
            state = .signedIn
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    func signUp(email: String, password: String) async {
        #if canImport(Supabase)
        guard let client else { return }
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            if response.session != nil {
                state = .signedIn
            } else {
                // Email confirmation is on: no session until the link is tapped.
                errorMessage = "Almost there — confirm the email we just sent, then sign in."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    func signOut() async {
        #if canImport(Supabase)
        guard let client else { return }
        try? await client.auth.signOut()
        state = .signedOut
        #endif
    }
}
