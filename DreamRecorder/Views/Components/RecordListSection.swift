import SwiftUI

/// ホーム画面の記録リストセクション（夢・日記の一覧表示）
struct RecordListSection: View {
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        ZStack {
            recordList
                .disabled(viewModel.isLoading)
            
            if viewModel.isLoading {
                ProgressView()
                    .tint(.dreamAccent)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Subviews
    
    private var recordList: some View {
        List {
            // 夢セクション: データがあれば表示、なければ追加プロンプト
            Section(header: EmptyView()) {
                if !viewModel.filteredDreams.isEmpty {
                    ForEach(viewModel.filteredDreams) { dream in
                        Button {
                            viewModel.navigateToDetail(for: dream.recordDate)
                        } label: {
                            CompactDreamRow(dream: dream)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete(perform: viewModel.deleteDreams)
                } else {
                    AddPromptRow(type: .dream) {
                        viewModel.showAddDreamSheet()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }
            
            // 日記セクション: データがあれば表示、なければ追加プロンプト
            Section(header: EmptyView()) {
                if !viewModel.filteredReflections.isEmpty {
                    ForEach(viewModel.filteredReflections) { reflection in
                        Button {
                            viewModel.navigateToDetail(for: reflection.recordDate)
                        } label: {
                            CompactReflectionRow(reflection: reflection)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete(perform: viewModel.deleteReflections)
                } else {
                    AddPromptRow(type: .reflection) {
                        viewModel.showAddReflectionSheet()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - CompactDreamRow

/// 夢のコンパクト表示行（1行のみ表示）
struct CompactDreamRow: View {
    let dream: Dream
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RecordTypeBadge(title: "夢")
                Spacer()
                NavigationArrowIcon()
            }
            
            Text(dream.content)
                .font(.dreamBody)
                .foregroundColor(.dreamText)
                .lineLimit(1)
            
            HStack {
                Text(Self.dateFormatter.string(from: dream.recordDate))
                    .font(.dreamCaption)
                    .foregroundColor(.dreamTextSecondary)
                Spacer()
            }
        }
        .compactRowStyle()
    }
}

// MARK: - CompactReflectionRow

/// 日記のコンパクト表示行（1行のみ表示）
struct CompactReflectionRow: View {
    let reflection: Reflection
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RecordTypeBadge(title: "日記")
                Spacer()
                NavigationArrowIcon()
            }
            
            Text(reflection.content)
                .font(.dreamBody)
                .foregroundColor(.dreamText)
                .lineLimit(1)
            
            HStack {
                Text(Self.dateFormatter.string(from: reflection.recordDate))
                    .font(.dreamCaption)
                    .foregroundColor(.dreamTextSecondary)
                Spacer()
            }
        }
        .compactRowStyle()
    }
}

// MARK: - AddPromptRow

/// 追加を促すプロンプト行（片方のデータがない場合に表示）
struct AddPromptRow: View {
    let type: RecordType
    let action: () -> Void
    
    enum RecordType {
        case dream
        case reflection
        
        var title: String {
            switch self {
            case .dream: return "夢"
            case .reflection: return "日記"
            }
        }
        
        var icon: String {
            switch self {
            case .dream: return "moon.zzz"
            case .reflection: return "square.and.pencil"
            }
        }
        
        var prompt: String {
            switch self {
            case .dream: return "夢を追加しましょう"
            case .reflection: return "日記を追加しましょう"
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.dreamAccent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.dreamAccent)
                    
                    Text(type.prompt)
                        .font(.dreamCaption)
                        .foregroundColor(.dreamTextSecondary)
                }
                
                Spacer()
                
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.dreamTextSecondary.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.dreamCard.opacity(0.3))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundColor(.dreamAccent.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared Components

/// 記録種別バッジ（夢/日記）
private struct RecordTypeBadge: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(.dreamAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.dreamAccent.opacity(0.15))
            .cornerRadius(10)
    }
}

/// ナビゲーション矢印アイコン
private struct NavigationArrowIcon: View {
    var body: some View {
        Image(systemName: "arrow.up.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.dreamAccent)
            .padding(8)
            .background(Color.white.opacity(0.1))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Compact Row Style

private extension View {
    /// コンパクト行の共通スタイルを適用
    func compactRowStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.dreamCard, Color.dreamCard.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}
