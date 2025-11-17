import SwiftUI

// 夢リストの行
struct DreamRow: View {
    let dream: Dream
    // サービスと認証情報にアクセスするためにEnvironmentObjectを追加
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dream.recordDate, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
                
            Text(dream.content)
                .font(.body)
                .lineLimit(3)
            
            // --- 夢占いUIの追加 ---
            if let interpretation = dream.interpretation {
                // 1. 解釈結果がある場合
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(.top, 2)
                    Text(interpretation)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
                .padding(.top, 4)
                
            } else if dreamService.interpretingDreamId == dream.id {
                // 2. 解釈中の場合
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8) // 小さく表示
                    Text("夢を分析中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
                
            } else {
                // 3. 「占う」ボタン
                Button {
                    Task {
                        // ボタンが押されたら占いを実行
                        guard let userId = authManager.userId else { return }
                        await dreamService.interpretDream(dream: dream, userId: userId)
                    }
                } label: {
                    Label("AIで夢を占う", systemImage: "sparkles")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .buttonStyle(.bordered)
                .controlSize(.small) // 小さなボタン
                .tint(.purple)
                .padding(.top, 4)
            }
            // --- ここまで ---
        }
        .padding(.vertical, 4)
    }
}
