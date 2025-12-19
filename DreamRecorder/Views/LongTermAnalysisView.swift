import SwiftUI

struct LongTermAnalysisView: View {
    var body: some View {
        ZStack {
            Color.clear.dreamBackground()
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.dreamAccent)
                Text("長期分析は準備中です。")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(.dreamText)
                Text("近日追加予定の機能です。")
                    .font(.dreamCaption)
                    .foregroundColor(.dreamTextSecondary)
            }
            .padding()
        }
        .navigationTitle("長期分析")
        .navigationBarTitleDisplayMode(.inline)
    }
}
