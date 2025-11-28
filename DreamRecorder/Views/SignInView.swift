import SwiftUI

// 簡易版・匿名ログイン
struct SignInView: View {
    @ObservedObject var authManager: AuthManager
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // 背景
            Color.clear.dreamBackground()
            
            VStack(spacing: 30) {
                Spacer()
                
                Image(uiImage: UIImage(named: "AppIcon") ?? UIImage()) // アプリアイコンを表示（もしあれば）
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .cornerRadius(24)
                    .shadow(color: .dreamAccent.opacity(0.5), radius: 20, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                VStack(spacing: 8) {
                    Text("Dream Recorder")
                        .font(.dreamTitle)
                        .foregroundColor(.dreamText)
                    
                    Text("あなたの夢を記録・分析します")
                        .font(.dreamBody)
                        .foregroundColor(.dreamTextSecondary)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .tint(.dreamAccent)
                } else {
                    Button {
                        Task {
                            await signIn()
                        }
                    } label: {
                        Text("はじめる")
                            .font(.dreamHeadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.dreamAccent)
                            .cornerRadius(16)
                            .shadow(color: .dreamAccent.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 40)
                }
                
                Spacer()
            }
            .padding()
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    @MainActor
    private func signIn() async {
        isLoading = true
        errorMessage = ""
        showError = false
        defer {
            isLoading = false
        }
        do {
            try await authManager.signInAnonymously()
        } catch {
            print("💥💥💥 サインイン失敗 (詳細): \(error) 💥💥💥")
            errorMessage = "ログインに失敗しました。ネットワーク接続を確認してください。"
            showError = true
        }
    }
}
