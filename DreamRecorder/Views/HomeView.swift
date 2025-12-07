import SwiftUI

private enum AddSheet: Identifiable {
    case dream
    case reflection
    
    var id: String {
        switch self {
        case .dream: return "dream"
        case .reflection: return "reflection"
        }
    }
}

// ホーム画面（カレンダーと当日の夢/日記リスト）
struct HomeView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var reflectionService: ReflectionService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showAddChoice = false
    @State private var activeSheet: AddSheet?
    @State private var dreamToEdit: Dream?
    @State private var reflectionToEdit: Reflection?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var navigateToDailyDetail = false
    @State private var detailDate: Date = Date()
    
    // 選択された日付を管理するState
    @State private var selectedDate: Date = Date()
    
    // 選択された日付に基づいて夢をフィルタリングする
    private var filteredDreams: [Dream] {
        dreamService.dreams.filter { dream in
            Calendar.current.isDate(dream.recordDate, inSameDayAs: selectedDate)
        }
    }
    
    private var filteredReflections: [Reflection] {
        reflectionService.reflections.filter { reflection in
            Calendar.current.isDate(reflection.recordDate, inSameDayAs: selectedDate)
        }
    }
    
    private var isLoading: Bool {
        dreamService.isLoading || reflectionService.isLoading
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.clear.dreamBackground()
                
                VStack(spacing: 0) {
                    // カレンダーUIの追加
                    DatePicker(
                        "日付選択",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .colorScheme(.dark)
                    .accentColor(.dreamAccent)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .padding()
                    
                    HStack {
                        Text("夢")
                            .font(.dreamBody)
                            .foregroundColor(.dreamText)
                        Spacer()
                        Button {
                            detailDate = selectedDate
                            navigateToDailyDetail = true
                        } label: {
                            Label("詳細を見る", systemImage: "arrow.right.circle.fill")
                                .font(.dreamBody)
                                .foregroundColor(.dreamAccent)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // フィルタリングされたリストの表示
                    ZStack {
                        // フィルタリングした結果、夢も日記もない場合に表示
                        if filteredDreams.isEmpty && filteredReflections.isEmpty && !isLoading {
                            VStack(spacing: 16) {
                                Image(systemName: "moon.zzz.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.dreamTextSecondary)
                                Text("この日の記録はありません")
                                    .font(.dreamHeadline)
                                    .foregroundColor(.dreamTextSecondary)
                                Text("下の + ボタンから夢や日記を追加しましょう")
                                    .font(.dreamCaption)
                                    .foregroundColor(.dreamTextSecondary)
                            }
                            .padding(.bottom, 60)
                        } else {
                            // フィルタリングされた夢/日記のリスト
                            List {
                                if !filteredDreams.isEmpty {
                                    Section {
                                        ForEach(filteredDreams) { dream in
                                            Button {
                                                self.dreamToEdit = dream
                                                self.activeSheet = .dream
                                            } label: {
                                                CompactDreamRow(dream: dream)
                                            }
                                            .buttonStyle(.plain)
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        }
                                        .onDelete(perform: deleteDreams)
                                    } header: { EmptyView() }
                                }
                                
                                if !filteredReflections.isEmpty {
                                    Section(header: Text("日記").foregroundColor(.dreamTextSecondary)) {
                                        ForEach(filteredReflections) { reflection in
                                            Button {
                                                self.reflectionToEdit = reflection
                                                self.activeSheet = .reflection
                                            } label: {
                                                CompactReflectionRow(reflection: reflection)
                                            }
                                            .buttonStyle(.plain)
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        }
                                        .onDelete(perform: deleteReflections)
                                    }
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
            }
            .navigationTitle("夢の記録")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToDailyDetail) {
                DailyDetailView(date: detailDate)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        self.dreamToEdit = nil
                        self.reflectionToEdit = nil
                        self.showAddChoice = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.dreamAccent)
                    }
                }
            }
            .confirmationDialog("追加する内容を選択", isPresented: $showAddChoice) {
                Button("夢を追加") {
                    self.dreamToEdit = nil
                    self.activeSheet = .dream
                }
                Button("日記を追加") {
                    self.reflectionToEdit = nil
                    self.activeSheet = .reflection
                }
                Button("キャンセル", role: .cancel) { }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .dream:
                    AddDreamView(recordDate: selectedDate, dreamToEdit: dreamToEdit)
                case .reflection:
                    AddReflectionView(recordDate: selectedDate, reflectionToEdit: reflectionToEdit)
                }
            }
            // 認証IDが変わった時、またはViewが最初に表示された時にリスナーをセットアップ
            .onChange(of: authManager.userId) {
                let userId = authManager.userId ?? ""
                dreamService.setupListener(userId: userId)
                reflectionService.setupListener(userId: userId)
            }
            .task {
                let userId = authManager.userId ?? ""
                dreamService.setupListener(userId: userId)
                reflectionService.setupListener(userId: userId)
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
    
    private func deleteDreams(at offsets: IndexSet) {
        guard let userId = authManager.userId else { return }
        
        let dreamsToDelete = offsets.map { filteredDreams[$0] }
        
        for dream in dreamsToDelete {
            Task {
                do {
                    try await dreamService.deleteDream(dream, userId: userId)
                } catch {
                    let appError: AppError
                    if let existingAppError = error as? AppError {
                        appError = existingAppError
                    } else {
                        appError = AppError.unknownError(error)
                    }
                    ErrorLogger.logError(appError, context: "HomeView.deleteDreams")
                    await MainActor.run {
                        errorMessage = ErrorLogger.userFacingMessage(from: appError)
                        showError = true
                    }
                }
            }
        }
}

private func deleteReflections(at offsets: IndexSet) {
        guard let userId = authManager.userId else { return }
        
        let reflectionsToDelete = offsets.map { filteredReflections[$0] }
        
        for reflection in reflectionsToDelete {
            Task {
                do {
                    try await reflectionService.deleteReflection(reflection, userId: userId)
                } catch {
                    let appError: AppError
                    if let existingAppError = error as? AppError {
                        appError = existingAppError
                    } else {
                        appError = AppError.unknownError(error)
                    }
                    ErrorLogger.logError(appError, context: "HomeView.deleteReflections")
                    await MainActor.run {
                        errorMessage = ErrorLogger.userFacingMessage(from: appError)
                        showError = true
                    }
                }
            }
        }
    }
}

// コンパクト表示用の行（1行のみ表示）
private struct CompactDreamRow: View {
    let dream: Dream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dream.recordDate, style: .date)
                .font(.dreamCaption)
                .foregroundColor(.dreamTextSecondary)
            Text(dream.content)
                .font(.dreamBody)
                .foregroundColor(.dreamText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.dreamCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct CompactReflectionRow: View {
    let reflection: Reflection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reflection.recordDate, style: .date)
                .font(.dreamCaption)
                .foregroundColor(.dreamTextSecondary)
            Text(reflection.content)
                .font(.dreamBody)
                .foregroundColor(.dreamText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.dreamCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
