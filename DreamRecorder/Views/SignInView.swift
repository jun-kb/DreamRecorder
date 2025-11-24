import SwiftUI

// 簡易版・匿名ログイン
struct SignInView: View {
    @ObservedObject var authManager: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
                Button("はじめる") {
                    Task {
                        await signIn()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top)
            }
        }
        .padding()
    }
    
    private func signIn() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }
        do {
            try await authManager.signInAnonymously()
        } catch {
            print("💥💥💥 サインイン失敗 (詳細): \(error) 💥💥💥")
            errorMessage = "ログインに失敗しました。ネットワーク接続を確認してください。"
        }
    }
}
