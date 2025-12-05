import SwiftUI

// AI分析画面（プレースホルダー）
struct AIAnalysisView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.clear.dreamBackground()
                
                VStack(spacing: 20) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundColor(.dreamTextSecondary)
                    
                    Text("AI分析")
                        .font(.dreamHeadline)
                        .foregroundColor(.dreamText)
                    
                    Text("夢の傾向や統計を分析します")
                        .font(.dreamBody)
                        .foregroundColor(.dreamTextSecondary)
                    
                    Text("（実装予定）")
                        .font(.dreamCaption)
                        .foregroundColor(.dreamTextSecondary)
                        .padding(.top, 8)
                }
            }
            .navigationTitle("AI分析")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

