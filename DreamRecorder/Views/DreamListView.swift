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

// カレンダーと夢/日記リスト
struct DreamListView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var reflectionService: ReflectionService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showAddChoice = false
    @State private var activeSheet: AddSheet?
    @State private var dreamToEdit: Dream?
    @State private var reflectionToEdit: Reflection?
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    // 1. 選択された日付を管理するState
    @State private var selectedDate: Date = Date()
    
    // 2. 選択された日付に基づいて夢をフィルタリングする
    private var filteredDreams: [Dream] {
        dreamService.dreams.filter { dream in
            // 夢の日付(recordDate)と選択された日付(selectedDate)が同じ日かどうかを判定
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
        NavigationView {
            // 3. カレンダーとリストを縦に並べる
            ZStack {
                // 背景
                Color.clear.dreamBackground()
                
                VStack(spacing: 0) {
                    // 4. カレンダーUIの追加
                    DatePicker(
                        "日付選択",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .colorScheme(.dark) // カレンダーをダークモード表示
                    .accentColor(.dreamAccent)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .padding()
                    
                    // 5. フィルタリングされたリストの表示
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
                                Text("右上の + ボタンから夢や日記を追加しましょう")
                                    .font(.dreamCaption)
                                    .foregroundColor(.dreamTextSecondary)
                            }
                            .padding(.bottom, 60)
                        } else {
                            // フィルタリングされた夢/日記のリスト
                            List {
                                if !filteredDreams.isEmpty {
                                    Section(header: Text("夢").foregroundColor(.dreamTextSecondary)) {
                                        ForEach(filteredDreams) { dream in
                                            Button{
                                                self.dreamToEdit = dream
                                                self.activeSheet = .dream
                                            } label: {
                                                DreamRow(dream: dream)
                                            }
                                            .buttonStyle(.plain)
                                            .listRowBackground(Color.clear) // リスト行の背景を透明に
                                            .listRowSeparator(.hidden)      // 区切り線を消す
                                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)) // 余白調整
                                        }
                                        .onDelete(perform: deleteDreams)
                                    }
                                }
                                
                                if !filteredReflections.isEmpty {
                                    Section(header: Text("日記").foregroundColor(.dreamTextSecondary)) {
                                        ForEach(filteredReflections) { reflection in
                                            Button{
                                                self.reflectionToEdit = reflection
                                                self.activeSheet = .reflection
                                            } label: {
                                                ReflectionRow(reflection: reflection)
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
                            .listStyle(.plain) // プレーンなリストスタイル
                            .scrollContentBackground(.hidden) // リスト自体の背景を隠す
                        }
                        
                        if isLoading {
                            ProgressView()
                                .tint(.dreamAccent)
                        }
                    }
                    // Listがカレンダーを押し出さないようにサイズを固定
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("夢の記録")
            .navigationBarTitleDisplayMode(.inline) // タイトルを小さく表示（好みで）
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
            // 認証IDが変わった時にリスナーをセットアップ
            .onChange(of: authManager.userId) {
                setupListeners()
            }
            // Viewが最初に表示された時にリスナーをセットアップ
            .onAppear {
                setupListeners()
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        // ナビゲーションバーのスタイル調整（UIKitのappearanceを使う必要がある場合もあるが、簡易的に）
        .accentColor(.dreamAccent)
        .preferredColorScheme(.dark) // ステータスバーとナビゲーションタイトルを白くする
    }
    
    private func deleteDreams(at offsets: IndexSet) {
        guard let userId = authManager.userId else { return }
        
        // フィルタリングされたリスト(filteredDreams)から削除対象の夢を取得
        let dreamsToDelete = offsets.map { filteredDreams[$0] }
        
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for dream in dreamsToDelete {
                        group.addTask {
                            try await dreamService.deleteDream(dream, userId: userId)
                        }
                    }
                    try await group.waitForAll()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "夢の削除に失敗しました。時間をおいて再度お試しください。"
                    self.showError = true
                    // デバッグ用にエラー詳細をログ出力します
                    print("夢の削除に失敗しました: \(error)")
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
                    await MainActor.run {
                        self.errorMessage = "日記の削除に失敗しました: \(error.localizedDescription)"
                        self.showError = true
                    }
                }
            }
        }
    }
    
    private func setupListeners() {
        let userId = authManager.userId ?? ""
        dreamService.setupListener(userId: userId)
        reflectionService.setupListener(userId: userId)
    }
}
