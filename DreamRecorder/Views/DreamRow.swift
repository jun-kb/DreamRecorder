import SwiftUI

// 夢リストの行
struct DreamRow: View {
    let dream: Dream
    // サービスと認証情報にアクセスするためにEnvironmentObjectを追加
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(dream.recordDate, style: .date)
                    .font(.dreamCaption)
                    .foregroundColor(.dreamTextSecondary)
                Spacer()
                // 曜日の表示などを追加しても良い
            }
                
            Text(dream.content)
                .font(.dreamBody)
                .foregroundColor(.dreamText)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // --- 夢占いUIの追加 ---
            if let interpretation = dream.interpretation {
                // 1. 解釈結果がある場合
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.dreamAccent)
                        .padding(.top, 2)
                    Text(interpretation)
                        .font(.dreamCaption)
                        .foregroundColor(.dreamText.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.dreamAccent.opacity(0.2))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dreamAccent.opacity(0.3), lineWidth: 1)
                )
                
            } else if dreamService.interpretingDreamId == dream.id {
                // 2. 解釈中の場合
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.dreamAccent)
                        .scaleEffect(0.8)
                    Text("夢を分析中...")
                        .font(.dreamCaption)
                        .foregroundColor(.dreamTextSecondary)
                }
                .padding(.top, 4)
                
            } else {
                // 3. 「占う」ボタン
                Button {
                    Task {
                        guard let userId = authManager.userId else { return }
                        do {
                            try await dreamService.interpretDream(dream: dream, userId: userId)
                        } catch {
                            // パターンA: エラーはdreamServiceのerrorMessageに設定され、
                            // DreamListViewのonChangeで表示されるため、ここでは何もしない
                            // （ログ記録はサービス層で実行済み）
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("AIで夢を占う")
                    }
                    .font(.dreamCaption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(20)
                    .shadow(color: .purple.opacity(0.4), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain) // List内でのボタン動作のため
                .padding(.top, 4)
            }
            // --- ここまで ---
        }
        .padding(16)
        .background(Color.dreamCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
