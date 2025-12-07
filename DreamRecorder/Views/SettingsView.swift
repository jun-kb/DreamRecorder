import SwiftUI

// 設定画面
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showLogoutAlert = false
    @State private var isLoggingOut = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.clear.dreamBackground()
                
                List {
                    // アカウントセクション
                    Section {
                        Button(role: .destructive) {
                            showLogoutAlert = true
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
        .alert("エラー", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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
                let appError = ErrorLogger.classify(error, context: .network)
                ErrorLogger.logError(appError, context: "SettingsView.logout")
                await MainActor.run {
                    errorMessage = ErrorLogger.userFacingMessage(from: appError)
                    showError = true
                }
            }
        }
    }
}

