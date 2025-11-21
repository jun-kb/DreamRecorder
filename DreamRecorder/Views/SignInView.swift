import SwiftUI

// 簡易版・匿名ログイン
struct SignInView: View {
    @ObservedObject var authManager: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingEmailAuth = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 80))
                .foregroundColor(.purple)
            
            Text("夢記録アプリ")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("あなたの夢を記録・分析します")
                .foregroundColor(.secondary)
            
            if isLoading {
                ProgressView()
            } else {
                VStack(spacing: 12) {
                    Button("はじめる（匿名）") {
                        Task {
                            await signIn()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("メール/パスワードでログイン") {
                        showingEmailAuth = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top)
            }
        }
        .padding()
        .sheet(isPresented: $showingEmailAuth) {
            EmailAuthView(authManager: authManager)
        }
    }
    
    private func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.signInAnonymously()
        } catch {
            print("💥💥💥 サインイン失敗 (詳細): \(error) 💥💥💥")
            isLoading = false
            errorMessage = "ログインに失敗しました。ネットワーク接続を確認してください。"
        }
    }
}
