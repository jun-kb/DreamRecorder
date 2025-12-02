import SwiftUI

// 認証状態に応じて SignInView か DreamListView を出し分ける
struct ContentView: View {
    // 必要なServiceをここで初期化
    @StateObject private var dreamService = DreamService()
    @StateObject private var reflectionService = ReflectionService()
    @StateObject private var authManager = AuthManager()
    
    var body: some View {
        Group {
            if authManager.isSignedIn {
                DreamListView()
                    // 必要なServiceを子ビューに渡す
                    .environmentObject(dreamService)
                    .environmentObject(reflectionService)
                    .environmentObject(authManager)
            } else {
                SignInView(authManager: authManager)
            }
        }
    }
}
