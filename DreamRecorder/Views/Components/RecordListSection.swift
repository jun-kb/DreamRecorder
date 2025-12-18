import SwiftUI

/// ホーム画面の記録リストセクション（夢・日記の一覧表示）
struct RecordListSection: View {
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        ZStack {
            if viewModel.filteredDreams.isEmpty && viewModel.filteredReflections.isEmpty && !viewModel.isLoading {
                EmptyRecordView(viewModel: viewModel)
            } else {
                recordList
            }
            
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
            if !viewModel.filteredDreams.isEmpty {
                Section(header: EmptyView()) {
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
                }
            }
            
            if !viewModel.filteredReflections.isEmpty {
                Section(header: EmptyView()) {
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
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - EmptyRecordView

/// 記録がない場合の空状態表示
struct EmptyRecordView: View {
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundColor(.dreamTextSecondary)
            Text("この日の記録はありません")
                .font(.dreamHeadline)
                .foregroundColor(.dreamTextSecondary)
            Text("夢や日記を追加して、この日の出来事を残しましょう。")
                .font(.dreamCaption)
                .foregroundColor(.dreamTextSecondary)
            
            HStack(spacing: 16) {
                Button {
                    viewModel.showAddDreamSheet()
                } label: {
                    Label("夢を追加", systemImage: "plus.circle.fill")
                        .font(.dreamCaption)
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.dreamAccent)
                
                Button {
                    viewModel.showAddReflectionSheet()
                } label: {
                    Label("日記を追加", systemImage: "square.and.pencil")
                        .font(.dreamCaption)
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.dreamAccent)
            }
            .padding()
        }
        .padding()
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
