import SwiftUI
import Combine
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

// 認証状態を一元管理するクラス
@MainActor
class AuthManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var userId: String?
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var isAnonymous = false
    @Published var isLinkedWithGoogle = false

    private var authHandle: AuthStateDidChangeListenerHandle?
    
    /// リンク失敗時に保持するCredential（既存アカウント切り替え用）
    private var pendingCredential: AuthCredential?

    init() {
        // 認証状態の変更をリッスン
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.isSignedIn = (user != nil)
            self?.userId = user?.uid
            self?.userEmail = user?.email
            self?.userName = user?.displayName
            self?.isAnonymous = user?.isAnonymous ?? false
            self?.isLinkedWithGoogle = user?.providerData.contains { $0.providerID == "google.com" } ?? false
        }
    }
    
    // MARK: - Google Sign-In
    
    func signInWithGoogle() async throws {
        let credential = try await performGoogleSignIn()
        try await Auth.auth().signIn(with: credential)
    }
    
    // MARK: - Anonymous Sign-In
    
    func signInAnonymously() async throws {
        guard !isSignedIn else { return }
        try await Auth.auth().signInAnonymously()
    }
    
    // MARK: - Link Anonymous Account with Google
    
    /// 匿名アカウントをGoogleアカウントにリンクする
    /// データは引き継がれ、同じuserIdを維持する
    /// - Throws: `AuthError.accountAlreadyExists` - Googleアカウントが既に別のユーザーに紐づいている場合
    func linkWithGoogle() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw AuthError.notSignedIn
        }
        
        guard currentUser.isAnonymous else {
            throw AuthError.alreadyLinked
        }
        
        let (credential, email) = try await performGoogleSignInWithEmail()
        
        do {
            // 匿名アカウントにGoogleアカウントをリンク
            // 状態は AuthStateDidChangeListener によって自動的に更新される
            try await currentUser.link(with: credential)
        } catch let error as NSError {
            // Googleアカウントが既に別のユーザーに紐づいている場合
            if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                // Credentialを保持して、後で切り替えられるようにする
                pendingCredential = credential
                throw AuthError.accountAlreadyExists(email: email)
            }
            throw error
        }
    }
    
    /// 既存のGoogleアカウントに切り替える
    /// 匿名アカウントのデータは破棄される
    func switchToExistingGoogleAccount() async throws {
        guard let credential = pendingCredential else {
            throw AuthError.noPendingCredential
        }
        
        // 匿名アカウントを削除（自動的にサインアウトされる）
        // これにより孤立した匿名アカウントがFirebase上に残ることを防ぐ
        try await Auth.auth().currentUser?.delete()
        
        // 既存のGoogleアカウントでサインイン
        try await Auth.auth().signIn(with: credential)
        
        // pendingCredentialをクリア
        pendingCredential = nil
    }
    
    /// 保留中のCredentialをクリアする
    func clearPendingCredential() {
        pendingCredential = nil
    }
    
    // MARK: - Private Helpers
    
    /// Googleサインインを実行してCredentialを取得する共通処理
    private func performGoogleSignIn() async throws -> AuthCredential {
        let (credential, _) = try await performGoogleSignInWithEmail()
        return credential
    }
    
    /// Googleサインインを実行してCredentialとメールアドレスを取得する共通処理
    private func performGoogleSignInWithEmail() async throws -> (AuthCredential, String?) {
        // FirebaseのclientIDを取得
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.configurationError
        }
        
        // GoogleSignInの設定
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // rootViewControllerを取得
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noRootViewController
        }
        
        // Googleサインインを実行
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        // idTokenを取得
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.invalidCredential
        }
        
        // Firebase認証用のCredentialを作成
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        
        return (credential, result.user.profile?.email)
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }
    
    deinit {
        // リスナーを解除
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError, Equatable {
    case configurationError
    case noRootViewController
    case invalidCredential
    case notSignedIn
    case alreadyLinked
    case accountAlreadyExists(email: String?)
    case noPendingCredential
    
    var errorDescription: String? {
        switch self {
        case .configurationError:
            return "Firebase の設定が見つかりません"
        case .noRootViewController:
            return "画面の取得に失敗しました"
        case .invalidCredential:
            return "認証情報が無効です"
        case .notSignedIn:
            return "サインインしていません"
        case .alreadyLinked:
            return "すでにアカウントがリンクされています"
        case .accountAlreadyExists(let email):
            if let email = email {
                return "\(email) は既に登録されています"
            }
            return "このGoogleアカウントは既に登録されています"
        case .noPendingCredential:
            return "切り替え可能なアカウント情報がありません"
        }
    }
    
    /// アカウントが既に存在するエラーかどうか
    var isAccountAlreadyExists: Bool {
        if case .accountAlreadyExists = self {
            return true
        }
        return false
    }
}
