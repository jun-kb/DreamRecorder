import SwiftUI

// 設定画面
struct SettingsView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showingAccountLink = false
    @State private var showingSignOutAlert = false
    @State private var isSendingVerification = false
    @State private var showingVerificationSent = false
    @State private var verificationError: String?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("アカウント情報")) {
                    if authManager.isAnonymous {
                        HStack {
                            Image(systemName: "person.circle")
                                .foregroundColor(.orange)
                            Text("匿名ユーザー")
                                .font(.body)
                        }
                        Text("データを保持するには、アカウントを登録することをおすすめします。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("登録済みアカウント")
                                        .font(.body)
                                    if let email = authManager.userEmail {
                                        Text(email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            // メール検証状態
                            if authManager.userEmail != nil {
                                HStack(spacing: 8) {
                                    Image(systemName: authManager.isEmailVerified ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                        .foregroundColor(authManager.isEmailVerified ? .green : .orange)
                                    Text(authManager.isEmailVerified ? "メールアドレスが確認済みです" : "メールアドレスの確認が必要です")
                                        .font(.caption)
                                        .foregroundColor(authManager.isEmailVerified ? .green : .orange)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                
                if authManager.isAnonymous {
                    Section(footer: Text("メールアドレスとパスワードでアカウントを登録すると、データが安全に保存され、他のデバイスからもアクセスできます。")) {
                        Button(action: {
                            showingAccountLink = true
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.blue)
                                Text("アカウントを登録")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                } else if !authManager.isEmailVerified {
                    Section(header: Text("メール検証"), footer: Text("メールアドレスの確認が完了していません。確認メールを再送信して、メール内のリンクをクリックしてください。")) {
                        Button(action: {
                            Task {
                                await sendVerificationEmail()
                            }
                        }) {
                            HStack {
                                if isSendingVerification {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.blue)
                                }
                                Text(isSendingVerification ? "送信中..." : "確認メールを再送信")
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(isSendingVerification)
                        
                        if let verificationError {
                            Text(verificationError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section(footer: Text(authManager.isAnonymous ? "ログアウトすると、匿名アカウントのデータにアクセスできなくなります。アカウントを登録することをおすすめします。" : "ログアウトすると、このデバイスからアカウントにアクセスできなくなります。")) {
                    Button(role: .destructive, action: {
                        showingSignOutAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("ログアウト")
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAccountLink) {
                AccountLinkView(authManager: authManager)
            }
            .alert("ログアウト", isPresented: $showingSignOutAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("ログアウト", role: .destructive) {
                    do {
                        try authManager.signOut()
                        dismiss()
                    } catch {
                        // エラーハンドリング（必要に応じて）
                        print("ログアウトエラー: \(error)")
                    }
                }
            } message: {
                if authManager.isAnonymous {
                    Text("ログアウトすると、匿名アカウントのデータにアクセスできなくなります。本当にログアウトしますか？")
                } else {
                    Text("本当にログアウトしますか？")
                }
            }
            .alert("確認メールを送信しました", isPresented: $showingVerificationSent) {
                Button("OK") { }
            } message: {
                Text("メールアドレスに確認メールを送信しました。メール内のリンクをクリックしてメールアドレスを確認してください。")
            }
            .onAppear {
                // 設定画面が表示された時にユーザー情報を再読み込み（メール検証状態を更新）
                Task {
                    try? await authManager.reloadUser()
                }
            }
            .onChange(of: showingAccountLink) { oldValue, newValue in
                // アカウント連携画面が閉じた時にユーザー情報を再読み込み
                if oldValue && !newValue {
                    Task {
                        try? await authManager.reloadUser()
                    }
                }
            }
        }
    }
    
    private func sendVerificationEmail() async {
        isSendingVerification = true
        verificationError = nil
        
        do {
            try await authManager.sendEmailVerification()
            // メール送信後、少し待ってからユーザー情報を再読み込み
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
            try? await authManager.reloadUser()
            await MainActor.run {
                showingVerificationSent = true
            }
        } catch {
            verificationError = "確認メールの送信に失敗しました: \(error.localizedDescription)"
        }
        
        isSendingVerification = false
    }
}

