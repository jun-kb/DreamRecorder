import SwiftUI

// 全夢一覧画面（プレースホルダー）
struct AllDreamsView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var reflectionService: ReflectionService
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.clear.dreamBackground()
                
                VStack(spacing: 20) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 60))
                        .foregroundColor(.dreamTextSecondary)
                    
                    Text("夢一覧")
                        .font(.dreamHeadline)
                        .foregroundColor(.dreamText)
                    
                    Text("全期間の夢と日記を一覧表示します")
                        .font(.dreamBody)
                        .foregroundColor(.dreamTextSecondary)
                    
                    Text("（実装予定）")
                        .font(.dreamCaption)
                        .foregroundColor(.dreamTextSecondary)
                        .padding(.top, 8)
                }
            }
            .navigationTitle("一覧")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

