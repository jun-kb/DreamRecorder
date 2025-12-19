import SwiftUI
import Combine

/// シート表示の種類を識別するenum
enum HomeAddSheet: Identifiable {
    case dream
    case reflection
    
    var id: String {
        switch self {
        case .dream: return "dream"
        case .reflection: return "reflection"
        }
    }
}

// MARK: - HomeViewModel
/// HomeViewの状態管理とビジネスロジックを集約するViewModel
@MainActor
final class HomeViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let dreamService: DreamService
    private let reflectionService: ReflectionService
    private let authManager: AuthManager
    
    // MARK: - Published State (カレンダー)
    @Published var selectedDate: Date = Date()
    @Published var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    
    // MARK: - Published State (ナビゲーション)
    @Published var navigateToDailyDetail = false
    @Published var detailDate: Date = Date()
    
    // MARK: - Published State (シート)
    @Published var activeSheet: HomeAddSheet?
    @Published var dreamToEdit: Dream?
    @Published var reflectionToEdit: Reflection?
    
    // MARK: - Published State (エラー)
    @Published var showError = false
    @Published var errorMessage = ""
    
    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// 選択日の夢をフィルタリング
    var filteredDreams: [Dream] {
        dreamService.dreams.filter { dream in
            Calendar.current.isDate(dream.recordDate, inSameDayAs: selectedDate)
        }
    }
    
    /// 選択日の日記をフィルタリング
    var filteredReflections: [Reflection] {
        reflectionService.reflections.filter { reflection in
            Calendar.current.isDate(reflection.recordDate, inSameDayAs: selectedDate)
        }
    }
    
    /// ローディング中かどうか
    var isLoading: Bool {
        dreamService.isLoading || reflectionService.isLoading
    }
    
    /// 選択日にデータがあるか
    var hasRecords: Bool {
        !filteredDreams.isEmpty || !filteredReflections.isEmpty
    }
    
    // MARK: - Initialization
    
    init(dreamService: DreamService, reflectionService: ReflectionService, authManager: AuthManager) {
        self.dreamService = dreamService
        self.reflectionService = reflectionService
        self.authManager = authManager
        
        setupErrorObservers()
    }
    
    // MARK: - Setup
    
    /// サービスのエラーを監視し、UIにエラーを表示する
    private func setupErrorObservers() {
        // DreamServiceのエラー監視
        dreamService.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = error
                self?.showError = true
                self?.dreamService.errorMessage = nil
            }
            .store(in: &cancellables)
        
        // ReflectionServiceのエラー監視
        reflectionService.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = error
                self?.showError = true
                self?.reflectionService.errorMessage = nil
            }
            .store(in: &cancellables)
        
        // DreamServiceのデータ変更を監視（カレンダーのインジケーター更新用）
        dreamService.$dreams
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // ReflectionServiceのデータ変更を監視（カレンダーのインジケーター更新用）
        reflectionService.$reflections
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    /// 認証状態に基づいてリスナーをセットアップ
    func setupListeners() {
        let userId = authManager.userId ?? ""
        dreamService.setupListener(userId: userId)
        reflectionService.setupListener(userId: userId)
    }
    
    // MARK: - Calendar Actions
    
    /// 表示月を前後にシフト
    func shiftMonth(by value: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = newMonth
    }
    
    /// 日付セルがタップされた時の処理
    /// - Parameter date: タップされた日付
    /// - Returns: 同じ日を再タップした場合true（詳細画面へ遷移）
    func handleDateTap(_ date: Date) {
        let isAlreadySelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        if isAlreadySelected {
            detailDate = date
            navigateToDailyDetail = true
        } else {
            selectedDate = date
        }
    }
    
    // MARK: - Sheet Actions
    
    /// 夢追加シートを表示
    func showAddDreamSheet() {
        dreamToEdit = nil
        activeSheet = .dream
    }
    
    /// 日記追加シートを表示
    func showAddReflectionSheet() {
        reflectionToEdit = nil
        activeSheet = .reflection
    }
    
    // MARK: - Navigation Actions
    
    /// 記録タップ時に詳細画面へ遷移
    func navigateToDetail(for date: Date) {
        detailDate = date
        navigateToDailyDetail = true
    }
    
    // MARK: - Delete Actions
    
    /// 夢を削除（リストのスワイプ削除用）
    func deleteDreams(at offsets: IndexSet) {
        guard let userId = authManager.userId else { return }
        
        let dreamsToDelete = offsets.map { filteredDreams[$0] }
        
        for dream in dreamsToDelete {
            Task {
                do {
                    try await dreamService.deleteDream(dream, userId: userId)
                } catch {
                    let appError = ErrorLogger.classify(error, context: .network)
                    ErrorLogger.logError(appError, context: "HomeViewModel.deleteDreams")
                    errorMessage = ErrorLogger.userFacingMessage(from: appError)
                    showError = true
                }
            }
        }
    }
    
    /// 日記を削除（リストのスワイプ削除用）
    func deleteReflections(at offsets: IndexSet) {
        guard let userId = authManager.userId else { return }
        
        let reflectionsToDelete = offsets.map { filteredReflections[$0] }
        
        for reflection in reflectionsToDelete {
            Task {
                do {
                    try await reflectionService.deleteReflection(reflection, userId: userId)
                } catch {
                    let appError = ErrorLogger.classify(error, context: .network)
                    ErrorLogger.logError(appError, context: "HomeViewModel.deleteReflections")
                    errorMessage = ErrorLogger.userFacingMessage(from: appError)
                    showError = true
                }
            }
        }
    }
}

// MARK: - Calendar Helpers

extension HomeViewModel {
    
    /// 月のパディング付き日付配列を生成
    /// - 月初の曜日に合わせて先頭にnilを挿入し、週の残り分も末尾にnil追加
    var monthDaysWithPadding: [Date?] {
        let calendar = Calendar.current
        let start = calendar.startOfMonth(for: displayedMonth)
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        
        let firstWeekday = calendar.component(.weekday, from: start)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
        
        var padded: [Date?] = Array(repeating: nil, count: offset)
        padded.append(contentsOf: days)
        
        // 7の倍数になるよう末尾にnilを追加
        let remainder = padded.count % 7
        if remainder != 0 {
            padded.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }
        return padded
    }
    
    /// 指定日に夢の記録があるかを判定
    func hasDream(for date: Date) -> Bool {
        let calendar = Calendar.current
        return dreamService.dreams.contains { calendar.isDate($0.recordDate, inSameDayAs: date) }
    }
    
    /// 指定日に日記の記録があるかを判定
    func hasReflection(for date: Date) -> Bool {
        let calendar = Calendar.current
        return reflectionService.reflections.contains { calendar.isDate($0.recordDate, inSameDayAs: date) }
    }
}
