import SwiftUI

// カレンダーと夢リスト
struct DreamListView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showingDreamSheet = false // 「追加」「編集」兼用
    @State private var dreamToEdit: Dream? = nil  // 編集対象の夢を保持
    
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
                        // フィルタリングした結果、夢がない場合に表示
                        if filteredDreams.isEmpty && !dreamService.isLoading {
                            VStack(spacing: 16) {
                                Image(systemName: "moon.zzz.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.dreamTextSecondary)
                                Text("この日の夢はありません")
                                    .font(.dreamHeadline)
                                    .foregroundColor(.dreamTextSecondary)
                                Text("右上の + ボタンから記録を始めましょう")
                                    .font(.dreamCaption)
                                    .foregroundColor(.dreamTextSecondary)
                            }
                            .padding(.bottom, 60)
                        } else {
                            // フィルタリングされた夢のリスト
                            List {
                                ForEach(filteredDreams) { dream in
                                    Button{
                                        self.dreamToEdit = dream
                                        self.showingDreamSheet = true
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
                            .listStyle(.plain) // プレーンなリストスタイル
                            .scrollContentBackground(.hidden) // リスト自体の背景を隠す
                        }
                        
                        if dreamService.isLoading {
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
                        self.showingDreamSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.dreamAccent)
                    }
                }
            }
            .sheet(isPresented: $showingDreamSheet) {
                AddDreamView(recordDate: selectedDate, dreamToEdit: dreamToEdit)
            }
            // 認証IDが変わった時、またはViewが最初に表示された時にリスナーをセットアップ
            .onChange(of: authManager.userId) {
                dreamService.setupListener(userId: authManager.userId ?? "")
            }
            .task {
                dreamService.setupListener(userId: authManager.userId ?? "")
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
        
        for dream in dreamsToDelete {
            Task {
                try? await dreamService.deleteDream(dream, userId: userId)
            }
        }
    }
}
