import SwiftUI

// 夢占い画面（プレースホルダー）
struct DreamFortuneView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.clear.dreamBackground()
                
                VStack(spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundColor(.dreamTextSecondary)
                    
                    Text("夢占い")
                        .font(.dreamHeadline)
                        .foregroundColor(.dreamText)
                    
                    Text("あなたの夢を占います")
                        .font(.dreamBody)
                        .foregroundColor(.dreamTextSecondary)
                    
                    Text("（実装予定）")
                        .font(.dreamCaption)
                        .foregroundColor(.dreamTextSecondary)
                        .padding(.top, 8)
                }
            }
            .navigationTitle("夢占い")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}
