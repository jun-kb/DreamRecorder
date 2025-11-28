import SwiftUI

// 振り返り日記の行表示
struct ReflectionRow: View {
    let reflection: Reflection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(reflection.recordDate, style: .date)
                    .font(.dreamCaption)
                    .foregroundColor(.dreamTextSecondary)
                Spacer()
            }
            
            Text(reflection.content)
                .font(.dreamBody)
                .foregroundColor(.dreamText)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
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
