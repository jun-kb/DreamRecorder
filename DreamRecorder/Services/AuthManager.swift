import SwiftUI
import Combine
import FirebaseAuth

// 認証状態を一元管理するクラス
@MainActor
class AuthManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var userId: String?
    
    private var authHandle: AuthStateDidChangeListenerHandle?
    
    // 現在のユーザーが匿名ユーザーかどうかを判定
    var isAnonymous: Bool {
        Auth.auth().currentUser?.isAnonymous ?? false
    }
    
    // 現在のユーザーのメールアドレスを取得
    var userEmail: String? {
        Auth.auth().currentUser?.email
    }
    
    // メールアドレスが検証済みかどうか
    var isEmailVerified: Bool {
        Auth.auth().currentUser?.isEmailVerified ?? false
    }
    
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
    
    // メール/パスワードで新規登録
    func createAccount(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        // 新規登録後にメール検証を送信
        try await result.user.sendEmailVerification()
    }
    
    // メール/パスワードでログイン
    func signInWithEmail(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    // 匿名ユーザーをメール/パスワードにリンク（本登録）
    func linkAnonymousUserWithEmail(email: String, password: String) async throws {
        guard let currentUser = Auth.auth().currentUser,
              currentUser.isAnonymous else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "匿名ユーザーではありません。"])
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await currentUser.link(with: credential)
        
        // リンク後にメール検証を送信
        try await currentUser.sendEmailVerification()
    }
    
    // メール検証メールを送信
    func sendEmailVerification() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーがログインしていません。"])
        }
        try await currentUser.sendEmailVerification()
    }
    
    // ユーザー情報を再読み込み（メール検証状態を更新）
    func reloadUser() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーがログインしていません。"])
        }
        try await currentUser.reload()
    }
    
    // ログアウト
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
