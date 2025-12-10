import SwiftUI

// 長期分析画面（プレースホルダー）
struct LongTermAnalysisView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.dreamBackground()
                
                VStack(spacing: 20) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 60))
                        .foregroundColor(.dreamTextSecondary)
                    
                    Text("長期分析")
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
            .navigationTitle("長期分析")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
