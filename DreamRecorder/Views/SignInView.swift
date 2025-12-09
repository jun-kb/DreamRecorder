import SwiftUI

// サインイン画面（Google / 匿名ログイン対応）
struct SignInView: View {
    @ObservedObject var authManager: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // 背景
            Color.clear.dreamBackground()
            
            VStack(spacing: 30) {
                Spacer()
                
                Image("AppIconImage")
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
                    VStack(spacing: 16) {
                        // Google サインインボタン
                        Button {
                            Task {
                                await signInWithGoogle()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "g.circle.fill")
                                    .font(.title2)
                                Text("Googleでサインイン")
                                    .font(.dreamHeadline)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                        }
                        
                        // 区切り線
                        HStack {
                            Rectangle()
                                .fill(Color.dreamTextSecondary.opacity(0.3))
                                .frame(height: 1)
                            Text("または")
                                .font(.dreamCaption)
                                .foregroundColor(.dreamTextSecondary)
                            Rectangle()
                                .fill(Color.dreamTextSecondary.opacity(0.3))
                                .frame(height: 1)
                        }
                        
                        // 匿名ログインボタン
                        Button {
                            Task {
                                await signInAnonymously()
                            }
                        } label: {
                            Text("ログインせずに始める")
                                .font(.dreamHeadline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.dreamAccent)
                                .cornerRadius(16)
                                .shadow(color: .dreamAccent.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                    }
                    .padding(.horizontal, 40)
                }
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.dreamCaption)
                        .foregroundColor(.red)
                        .padding(.top)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Sign-In Methods
    
    private func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }
        do {
            try await authManager.signInWithGoogle()
        } catch {
            let appError = ErrorLogger.classify(error, context: .auth)
            ErrorLogger.logError(appError, context: "SignInView.signInWithGoogle")
            errorMessage = ErrorLogger.userFacingMessage(from: appError)
        }
    }
    
    private func signInAnonymously() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }
        do {
            try await authManager.signInAnonymously()
        } catch {
            let appError = ErrorLogger.classify(error, context: .auth)
            ErrorLogger.logError(appError, context: "SignInView.signInAnonymously")
            errorMessage = ErrorLogger.userFacingMessage(from: appError)
        }
    }
}
