import SwiftUI

// 匿名ユーザーをメール/パスワードにリンクする画面
struct AccountLinkView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("アカウント情報")) {
                    Text("匿名で使用中のデータを保持したまま、メールアドレスとパスワードで本登録できます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("メールアドレスとパスワード")) {
                    TextField("メールアドレス", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("パスワード", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("パスワード（確認）", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                
                Section {
                    Button(action: {
                        Task {
                            await linkAccount()
                        }
                    }) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Text("登録中...")
                                    .padding(.leading, 8)
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("本登録する")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                    .disabled(isLoading || !isValidInput)
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("アカウントを登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .alert("メール検証を送信しました", isPresented: $showingVerificationSent) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("登録したメールアドレスに確認メールを送信しました。メール内のリンクをクリックしてメールアドレスを確認してください。")
            }
        }
    }
    
    private var isValidInput: Bool {
        !email.isEmpty && 
        !password.isEmpty && 
        !confirmPassword.isEmpty &&
        isValidEmail(email) &&
        password == confirmPassword &&
        password.count >= 6
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func linkAccount() async {
        guard isValidInput else {
            if !isValidEmail(email) {
                errorMessage = "有効なメールアドレスを入力してください。"
            } else if password != confirmPassword {
                errorMessage = "パスワードが一致しません。"
            } else if password.count < 6 {
                errorMessage = "パスワードは6文字以上で入力してください。"
            } else {
                errorMessage = "すべての項目を入力してください。"
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authManager.linkAnonymousUserWithEmail(email: email, password: password)
            // リンク成功後、ユーザー情報を再読み込み（メールアドレスなどの情報を更新）
            try? await authManager.reloadUser()
            // メール検証メールが送信されたことをユーザーに通知
            await MainActor.run {
                showingVerificationSent = true
            }
        } catch {
            errorMessage = getErrorMessage(from: error)
            isLoading = false
        }
    }
    
    @State private var showingVerificationSent = false
    
    private func getErrorMessage(from error: Error) -> String {
        if let authError = error as NSError? {
            switch authError.code {
            case 17007: // メールアドレスが既に使用されている
                return "このメールアドレスは既に登録されています。"
            case 17008: // 無効なメールアドレス
                return "有効なメールアドレスを入力してください。"
            case 17010: // パスワードが弱すぎる
                return "パスワードは6文字以上で入力してください。"
            case 17020: // ネットワークエラー
                return "ネットワークエラーが発生しました。接続を確認してください。"
            case 17025: // 匿名ユーザーではない
                return "既にアカウントが登録されています。"
            default:
                return "登録に失敗しました: \(authError.localizedDescription)"
            }
        }
        return "登録に失敗しました。"
    }
}

