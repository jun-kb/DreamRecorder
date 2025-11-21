import SwiftUI

// 認証状態に応じて SignInView か DreamListView を出し分ける
struct ContentView: View {
    // 必要なServiceをここで初期化
    @StateObject private var dreamService = DreamService()
    @StateObject private var authManager = AuthManager()
    
    var body: some View {
        Group {
            if authManager.isSignedIn {
                DreamListView()
                    // 必要なServiceを子ビューに渡す
                    .environmentObject(dreamService)
                    .environmentObject(authManager)
            } else {
                SignInView(authManager: authManager)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // アプリがフォアグラウンドに戻った時にユーザー情報を再読み込み
            // （メール検証リンクをクリックした後など）
            Task {
                if authManager.isSignedIn {
                    try? await authManager.reloadUser()
                }
            }
        }
    }
}
