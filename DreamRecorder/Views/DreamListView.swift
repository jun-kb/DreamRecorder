import SwiftUI

// カレンダーと夢リスト
struct DreamListView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showingDreamSheet = false // 「追加」「編集」兼用
    @State private var dreamToEdit: Dream? = nil  // 編集対象の夢を保持
    @State private var showingAccountLink = false // アカウント連携画面の表示
    
    // 1. 選択された日付を管理するState
    @State private var selectedDate: Date = Date()
    
    // 2. 選択された日付に基づいて夢をフィルタリングする
    private var filteredDreams: [Dream] {
        dreamService.dreams.filter { dream in
            // 夢の日付(recordDate)と選択された日付(selectedDate)が同じ日かどうかを判定
            Calendar.current.isDate(dream.recordDate, inSameDayAs: selectedDate)
        }
    }
    
    var body: some View {
        NavigationView {
            // 3. カレンダーとリストを縦に並べる
            VStack {
                // 4. カレンダーUIの追加
                DatePicker(
                    "日付選択",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical) // これでカレンダー表示になる
                .padding(.horizontal)
                
                // 5. フィルタリングされたリストの表示
                ZStack {
                    // フィルタリングした結果、夢がない場合に表示
                    if filteredDreams.isEmpty && !dreamService.isLoading {
                        VStack(spacing: 16) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("この日の夢はありません")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("右上の + ボタンから記録を始めましょう")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 60) // カレンダーの下に表示されるよう調整
                    } else {
                        // フィルタリングされた夢のリスト
                        List {
                            ForEach(filteredDreams) { dream in
                                Button{
                                    self.dreamToEdit = dream
                                    self.showingDreamSheet = true
                                } label: {
                                    DreamRow(dream: dream)
                                        // DreamRowにEnvironmentObjectを渡す
                                        // ※ContentViewから渡されているので、ここでは不要だが
                                        //   可読性のために残しても良い
                                        // .environmentObject(dreamService)
                                        // .environmentObject(authManager)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete(perform: deleteDreams)
                        }
                    }
                    
                    if dreamService.isLoading {
                        ProgressView()
                    }
                }
                // Listがカレンダーを押し出さないようにサイズを固定
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("夢の記録")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingAccountLink = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        self.dreamToEdit = nil
                        self.showingDreamSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingDreamSheet) {
                AddDreamView(recordDate: selectedDate, dreamToEdit: dreamToEdit)
                    // .environmentObject(dreamService) // 環境オブジェクトは自動で引き継がれる
                    // .environmentObject(authManager)
            }
            .sheet(isPresented: $showingAccountLink) {
                SettingsView(authManager: authManager)
            }
            // 認証IDが変わった時、またはViewが最初に表示された時にリスナーをセットアップ
            .onChange(of: authManager.userId) {
                dreamService.setupListener(userId: authManager.userId ?? "")
            }
            .task {
                dreamService.setupListener(userId: authManager.userId ?? "")
            }
        }
    }
    
    private func deleteDreams(at offsets: IndexSet) {
        guard let userId = authManager.userId else { return }
        
        // フィルタリングされたリスト(filteredDreams)から削除対象の夢を取得
        let dreamsToDelete = offsets.map { filteredDreams[$0] }
        
        for dream in dreamsToDelete {
            Task {
                try? await dreamService.deleteDream(dream, userId: userId)
            }
        }
    }
}
