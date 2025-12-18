import SwiftUI

// MARK: - HomeView
/// ホーム画面（カレンダーと当日の夢/日記リスト）
struct HomeView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var reflectionService: ReflectionService
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        HomeViewContent(
            dreamService: dreamService,
            reflectionService: reflectionService,
            authManager: authManager
        )
    }
}

// MARK: - HomeViewContent
/// EnvironmentObjectを受け取って実際の描画を行う内部View
private struct HomeViewContent: View {
    @ObservedObject var dreamService: DreamService
    @ObservedObject var reflectionService: ReflectionService
    @ObservedObject var authManager: AuthManager
    
    @StateObject private var viewModel: HomeViewModel
    
    init(dreamService: DreamService, reflectionService: ReflectionService, authManager: AuthManager) {
        self.dreamService = dreamService
        self.reflectionService = reflectionService
        self.authManager = authManager
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            dreamService: dreamService,
            reflectionService: reflectionService,
            authManager: authManager
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.dreamBackground()
                
                VStack(spacing: 0) {
                    CalendarSection(viewModel: viewModel)
                    RecordListSection(viewModel: viewModel)
                }
            }
            .navigationTitle("夢の記録")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $viewModel.navigateToDailyDetail) {
                DailyDetailView(date: viewModel.detailDate)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    addMenu
                }
            }
            .sheet(item: $viewModel.activeSheet) { sheet in
                sheetContent(for: sheet)
            }
            .onChange(of: authManager.userId) {
                viewModel.setupListeners()
            }
            .task {
                viewModel.setupListeners()
            }
        }
        .accentColor(.dreamAccent)
        .preferredColorScheme(.dark)
        .alert("エラー", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - Subviews
    
    /// 追加メニュー（夢追加/日記追加）
    private var addMenu: some View {
        Menu {
            Button {
                viewModel.showAddDreamSheet()
            } label: {
                Label("夢を追加", systemImage: "plus.circle")
            }
            
            Button {
                viewModel.showAddReflectionSheet()
            } label: {
                Label("日記を追加", systemImage: "square.and.pencil")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.dreamAccent)
        }
    }
    
    /// シート内容の生成
    @ViewBuilder
    private func sheetContent(for sheet: HomeAddSheet) -> some View {
        switch sheet {
        case .dream:
            AddDreamView(recordDate: viewModel.selectedDate, dreamToEdit: viewModel.dreamToEdit)
        case .reflection:
            AddReflectionView(recordDate: viewModel.selectedDate, reflectionToEdit: viewModel.reflectionToEdit)
        }
    }
}

// MARK: - Calendar Extension

extension Calendar {
    /// 指定日付の月初を取得
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
