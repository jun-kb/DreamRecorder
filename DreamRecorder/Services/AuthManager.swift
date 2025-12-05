import SwiftUI
import Combine
import FirebaseAuth

// 認証状態を一元管理するクラス
@MainActor
class AuthManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var userId: String?

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        // 認証状態の変更をリッスン
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.isSignedIn = (user != nil)
            self?.userId = user?.uid
        }
    }
    
    func signInAnonymously() async throws {
        guard !isSignedIn else { return }
        try await Auth.auth().signInAnonymously()
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    deinit {
        // リスナーを解除
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }
}
