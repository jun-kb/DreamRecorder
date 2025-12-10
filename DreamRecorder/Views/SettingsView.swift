import SwiftUI

// 設定画面
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showLogoutAlert = false
    @State private var showAnonymousLogoutAlert = false
    @State private var isLoggingOut = false
    @State private var isLinking = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showLinkSuccessAlert = false
    @State private var showAccountExistsAlert = false
    @State private var accountExistsEmail: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.clear.dreamBackground()
                
                List {
                    // アカウントセクション
                    Section {
                        // アカウント状態の表示
                        if authManager.isAnonymous {
                            // 匿名ユーザー向け: Googleアカウントリンク
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "person.crop.circle.badge.questionmark")
                                        .foregroundColor(.dreamTextSecondary)
                                    Text("ゲストとしてログイン中")
                                        .foregroundColor(.dreamText)
                                }
                                
                                Text("Googleアカウントに連携すると、機種変更時もデータを引き継げます")
                                    .font(.dreamCaption)
                                    .foregroundColor(.dreamTextSecondary)
                            }
                            .padding(.vertical, 4)
                            
                            // Googleアカウントリンクボタン
                            Button {
                                Task {
                                    await linkWithGoogle()
                                }
                            } label: {
                                HStack {
                                    if isLinking {
                                        ProgressView()
                                            .tint(.dreamText)
                                    } else {
                                        Image(systemName: "g.circle.fill")
                                        Text("Googleアカウントに連携")
                                    }
                                }
                            }
                            .disabled(isLinking)
                        } else {
                            // Googleアカウントでログイン済み
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "person.crop.circle.fill.badge.checkmark")
                                        .foregroundColor(.green)
                                    Text("Googleアカウントでログイン中")
                                        .foregroundColor(.dreamText)
                                }
                                
                                if let email = authManager.userEmail {
                                    Text(email)
                                        .font(.dreamCaption)
                                        .foregroundColor(.dreamTextSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // ログアウトボタン
                        Button(role: .destructive) {
                            if authManager.isAnonymous {
                                showAnonymousLogoutAlert = true
                            } else {
                                showLogoutAlert = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("ログアウト")
                            }
                        }
                        .disabled(isLoggingOut)
                    } header: {
                        Text("アカウント")
                            .foregroundColor(.dreamTextSecondary)
                    }
                    .listRowBackground(Color.dreamCard)
                    
                    // アプリ情報セクション
                    Section {
                        HStack {
                            Text("バージョン")
                                .foregroundColor(.dreamText)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundColor(.dreamTextSecondary)
                        }
                    } header: {
                        Text("アプリ情報")
                            .foregroundColor(.dreamTextSecondary)
                    }
                    .listRowBackground(Color.dreamCard)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .alert("ログアウト", isPresented: $showLogoutAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("ログアウト", role: .destructive) {
                logout()
            }
        } message: {
            Text("ログアウトしてもよろしいですか？")
        }
        .alert("⚠️ データが失われます", isPresented: $showAnonymousLogoutAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("Googleに連携", role: .none) {
                Task {
                    await linkWithGoogle()
                }
            }
            Button("ログアウト", role: .destructive) {
                logout()
            }
        } message: {
            Text("ゲストとしてログイン中のため、ログアウトすると記録した夢のデータに二度とアクセスできなくなります。\n\nGoogleアカウントに連携してデータを保存することをおすすめします。")
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("連携完了", isPresented: $showLinkSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Googleアカウントとの連携が完了しました。データは引き継がれています。")
        }
        .alert("このアカウントは既に登録されています", isPresented: $showAccountExistsAlert) {
            Button("キャンセル", role: .cancel) {
                authManager.clearPendingCredential()
            }
            Button("別のアカウントで連携") {
                authManager.clearPendingCredential()
                Task {
                    await linkWithGoogle()
                }
            }
            Button("既存アカウントに切り替え", role: .destructive) {
                Task {
                    await switchToExistingAccount()
                }
            }
        } message: {
            if let email = accountExistsEmail {
                Text("\(email) は既に別のアカウントで使用されています。\n\n別のGoogleアカウントで連携するか、既存のアカウントに切り替えることができます。\n\n⚠️ 切り替えると、現在のゲストアカウントのデータにはアクセスできなくなります。")
            } else {
                Text("このGoogleアカウントは既に別のアカウントで使用されています。\n\n別のGoogleアカウントで連携するか、既存のアカウントに切り替えることができます。\n\n⚠️ 切り替えると、現在のゲストアカウントのデータにはアクセスできなくなります。")
            }
        }
    }
    
    // MARK: - Actions
    
    private func linkWithGoogle() async {
        isLinking = true
        defer {
            isLinking = false
        }
        
        do {
            try await authManager.linkWithGoogle()
            showLinkSuccessAlert = true
        } catch let error as AuthError {
            // アカウント既存エラーの場合は専用アラートを表示
            if case .accountAlreadyExists(let email) = error {
                accountExistsEmail = email
                showAccountExistsAlert = true
            } else {
                let appError = ErrorLogger.classify(error, context: .auth)
                ErrorLogger.logError(appError, context: "SettingsView.linkWithGoogle")
                errorMessage = ErrorLogger.userFacingMessage(from: appError)
                showError = true
            }
        } catch {
            let appError = ErrorLogger.classify(error, context: .auth)
            ErrorLogger.logError(appError, context: "SettingsView.linkWithGoogle")
            errorMessage = ErrorLogger.userFacingMessage(from: appError)
            showError = true
        }
    }
    
    private func switchToExistingAccount() async {
        isLinking = true
        defer {
            isLinking = false
        }
        
        do {
            try await authManager.switchToExistingGoogleAccount()
        } catch {
            let appError = ErrorLogger.classify(error, context: .auth)
            ErrorLogger.logError(appError, context: "SettingsView.switchToExistingAccount")
            errorMessage = ErrorLogger.userFacingMessage(from: appError)
            showError = true
        }
    }
    
    private func logout() {
        isLoggingOut = true
        
        Task {
            defer {
                Task { @MainActor in
                    isLoggingOut = false
                }
            }
            
            do {
                try authManager.signOut()
            } catch {
                let appError = ErrorLogger.classify(error, context: .auth)
                ErrorLogger.logError(appError, context: "SettingsView.logout")
                await MainActor.run {
                    errorMessage = ErrorLogger.userFacingMessage(from: appError)
                    showError = true
                }
            }
        }
    }
}

