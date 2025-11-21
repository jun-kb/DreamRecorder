import SwiftUI

// メール/パスワード認証画面
struct EmailAuthView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false // true: 新規登録, false: ログイン
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingVerificationSent = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("メールアドレス", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("パスワード", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                }
                
                Section {
                    Button(action: {
                        Task {
                            await authenticate()
                        }
                    }) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Text(isSignUp ? "登録中..." : "ログイン中...")
                                    .padding(.leading, 8)
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text(isSignUp ? "新規登録" : "ログイン")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                    .disabled(isLoading || !isValidInput)
                }
                
                Section {
                    Button(action: {
                        isSignUp.toggle()
                        errorMessage = nil
                    }) {
                        HStack {
                            Spacer()
                            Text(isSignUp ? "既にアカウントをお持ちの方はログイン" : "アカウントをお持ちでない方は新規登録")
                                .font(.caption)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isSignUp ? "新規登録" : "ログイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .alert("確認メールを送信しました", isPresented: $showingVerificationSent) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("登録したメールアドレスに確認メールを送信しました。メール内のリンクをクリックしてメールアドレスを確認してください。")
            }
        }
    }
    
    private var isValidInput: Bool {
        !email.isEmpty && !password.isEmpty && isValidEmail(email)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func authenticate() async {
        guard isValidInput else {
            errorMessage = "メールアドレスとパスワードを入力してください。"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if isSignUp {
                try await authManager.createAccount(email: email, password: password)
                // 新規登録後、ユーザー情報を再読み込み
                try? await authManager.reloadUser()
                // 新規登録時はメール検証メールが送信されたことを通知
                await MainActor.run {
                    showingVerificationSent = true
                }
            } else {
                try await authManager.signInWithEmail(email: email, password: password)
                // ログイン後、ユーザー情報を再読み込み（メール検証状態などを更新）
                try? await authManager.reloadUser()
                // ログイン成功時はそのまま閉じる
                dismiss()
            }
        } catch {
            errorMessage = getErrorMessage(from: error)
            isLoading = false
        }
    }
    
    private func getErrorMessage(from error: Error) -> String {
        if let authError = error as NSError? {
            switch authError.code {
            case 17007: // メールアドレスが既に使用されている
                return "このメールアドレスは既に登録されています。"
            case 17008: // 無効なメールアドレス
                return "有効なメールアドレスを入力してください。"
            case 17009: // 間違ったパスワード
                return "メールアドレスまたはパスワードが正しくありません。"
            case 17010: // パスワードが弱すぎる
                return "パスワードは6文字以上で入力してください。"
            case 17020: // ネットワークエラー
                return "ネットワークエラーが発生しました。接続を確認してください。"
            default:
                return "認証に失敗しました: \(authError.localizedDescription)"
            }
        }
        return "認証に失敗しました。"
    }
}

