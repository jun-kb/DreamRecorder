import SwiftUI

// MARK: - Filter & Sort Enums

/// セグメントコントロール用のフィルター
private enum ListFilter: String, CaseIterable {
    case all = "すべて"
    case dreams = "夢"
    case reflections = "日記"
}

/// ソート順
private enum SortOrder: String, CaseIterable {
    case newest = "新しい順"
    case oldest = "古い順"
    
    var icon: String {
        switch self {
        case .newest: return "arrow.down"
        case .oldest: return "arrow.up"
        }
    }
}

// MARK: - ListItem (統合型)

/// 夢と日記を統一的に扱うためのラッパー型
/// structを使用してIDを作成時に固定し、ナビゲーションの安定性を確保
private struct ListItem: Identifiable {
    let id: String
    let recordDate: Date
    let content: ListItemContent
    
    enum ListItemContent {
        case dream(Dream)
        case reflection(Reflection)
    }
    
    init(dream: Dream) {
        // IDを作成時に固定（dream.idがnilの場合は内容のハッシュ値を使用）
        self.id = "dream-\(dream.id ?? "stable-\(dream.content.hashValue)-\(Int(dream.recordDate.timeIntervalSince1970))")"
        self.recordDate = dream.recordDate
        self.content = .dream(dream)
    }
    
    init(reflection: Reflection) {
        // IDを作成時に固定（reflection.idがnilの場合は内容のハッシュ値を使用）
        self.id = "reflection-\(reflection.id ?? "stable-\(reflection.content.hashValue)-\(Int(reflection.recordDate.timeIntervalSince1970))")"
        self.recordDate = reflection.recordDate
        self.content = .reflection(reflection)
    }
}

// MARK: - AllDreamsView

/// 全夢・日記一覧画面
struct AllDreamsView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var reflectionService: ReflectionService
    @EnvironmentObject var authManager: AuthManager
    
    // MARK: - State
    
    @State private var selectedFilter: ListFilter = .all
    @State private var sortOrder: SortOrder = .newest
    @State private var navigateToDailyDetail = false
    @State private var detailDate: Date = Date()
    @State private var showError = false
    @State private var errorMessage = ""
    
    // MARK: - Computed Properties
    
    private var isLoading: Bool {
        dreamService.isLoading || reflectionService.isLoading
    }
    
    /// フィルター＆ソート適用後のリスト
    private var filteredAndSortedItems: [ListItem] {
        var items: [ListItem] = []
        
        // フィルター適用
        switch selectedFilter {
        case .all:
            items = dreamService.dreams.map { ListItem(dream: $0) }
                  + reflectionService.reflections.map { ListItem(reflection: $0) }
        case .dreams:
            items = dreamService.dreams.map { ListItem(dream: $0) }
        case .reflections:
            items = reflectionService.reflections.map { ListItem(reflection: $0) }
        }
        
        // ソート適用
        switch sortOrder {
        case .newest:
            items.sort { $0.recordDate > $1.recordDate }
        case .oldest:
            items.sort { $0.recordDate < $1.recordDate }
        }
        
        return items
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.clear.dreamBackground()
                
                VStack(spacing: 0) {
                    // コントロールエリア（セグメント + ソート）
                    controlSection
                    
                    // リストエリア
                    listSection
                }
            }
            .navigationTitle("一覧")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToDailyDetail) {
                DailyDetailView(date: detailDate)
            }
        }
        .accentColor(.dreamAccent)
        .preferredColorScheme(.dark)
        .alert("エラー", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: dreamService.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
                showError = true
                dreamService.errorMessage = nil
            }
        }
        .onChange(of: reflectionService.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
                showError = true
                reflectionService.errorMessage = nil
            }
        }
    }
}

// MARK: - Subviews

private extension AllDreamsView {
    
    /// コントロールセクション（セグメント + ソートボタン）
    var controlSection: some View {
        VStack(spacing: 12) {
            // セグメントコントロール
            Picker("フィルター", selection: $selectedFilter) {
                ForEach(ListFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            
            // ソートボタン（タップで切り替え）
            HStack {
                Spacer()
                
                Button {
                    // タップで新しい順↔古い順を切り替え
                    sortOrder = (sortOrder == .newest) ? .oldest : .newest
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: sortOrder.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(sortOrder.rawValue)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.dreamAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    /// リストセクション
    var listSection: some View {
        ZStack {
            if filteredAndSortedItems.isEmpty && !isLoading {
                emptyStateView
            } else {
                List {
                    ForEach(filteredAndSortedItems) { item in
                        Button {
                            detailDate = item.recordDate
                            navigateToDailyDetail = true
                        } label: {
                            listRow(for: item)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            
            if isLoading {
                ProgressView()
                    .tint(.dreamAccent)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    /// 空状態ビュー
    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.dreamTextSecondary)
            
            Text(emptyStateTitle)
                .font(.dreamHeadline)
                .foregroundColor(.dreamTextSecondary)
            
            Text(emptyStateMessage)
                .font(.dreamCaption)
                .foregroundColor(.dreamTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
    
    /// 空状態のアイコン
    var emptyStateIcon: String {
        switch selectedFilter {
        case .all:
            return "moon.zzz.fill"
        case .dreams:
            return "moon.stars.fill"
        case .reflections:
            return "book.closed.fill"
        }
    }
    
    /// 空状態のタイトル
    var emptyStateTitle: String {
        switch selectedFilter {
        case .all:
            return "記録がありません"
        case .dreams:
            return "夢の記録がありません"
        case .reflections:
            return "日記がありません"
        }
    }
    
    /// 空状態のメッセージ
    var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return "ホーム画面から夢や日記を追加しましょう"
        case .dreams:
            return "ホーム画面から夢を追加しましょう"
        case .reflections:
            return "ホーム画面から日記を追加しましょう"
        }
    }
    
    /// リスト行の表示
    @ViewBuilder
    func listRow(for item: ListItem) -> some View {
        switch item.content {
        case .dream(let dream):
            AllDreamsListRow(
                type: .dream,
                content: dream.content,
                recordDate: dream.recordDate
            )
        case .reflection(let reflection):
            AllDreamsListRow(
                type: .reflection,
                content: reflection.content,
                recordDate: reflection.recordDate
            )
        }
    }
}

// MARK: - AllDreamsListRow

/// 一覧用の行コンポーネント
private struct AllDreamsListRow: View {
    enum RowType {
        case dream
        case reflection
        
        var label: String {
            switch self {
            case .dream: return "夢"
            case .reflection: return "日記"
            }
        }
    }
    
    let type: RowType
    let content: String
    let recordDate: Date
    
    /// 日付フォーマッター（短い形式: 2025/12/06）
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(type.label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.dreamAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.dreamAccent.opacity(0.15))
                    .cornerRadius(10)
                
                Spacer()
                
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
            
            Text(content)
                .font(.dreamBody)
                .foregroundColor(.dreamText)
                .lineLimit(2)
            
            HStack {
                Text(Self.dateFormatter.string(from: recordDate))
                    .font(.dreamCaption)
                    .foregroundColor(.dreamTextSecondary)
                Spacer()
            }
        }
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
