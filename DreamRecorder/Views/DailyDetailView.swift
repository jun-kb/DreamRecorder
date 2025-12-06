import SwiftUI

private enum DailySheet: Identifiable {
    case dream
    case reflection
    
    var id: String {
        switch self {
        case .dream: return "dream"
        case .reflection: return "reflection"
        }
    }
}

struct DailyDetailView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var reflectionService: ReflectionService
    @EnvironmentObject var authManager: AuthManager
    
    let date: Date
    
    @State private var activeSheet: DailySheet?
    @State private var dreamToEdit: Dream?
    @State private var reflectionToEdit: Reflection?
    @State private var dreamPendingDelete: Dream?
    @State private var reflectionPendingDelete: Reflection?
    @State private var showDreamDeleteConfirm = false
    @State private var showReflectionDeleteConfirm = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var currentDate: Date
    
    init(date: Date) {
        self.date = date
        _currentDate = State(initialValue: date)
    }
    
    private var dreamsForDay: [Dream] {
        dreamService.dreams.filter { Calendar.current.isDate($0.recordDate, inSameDayAs: currentDate) }
    }
    
    private var reflectionsForDay: [Reflection] {
        reflectionService.reflections.filter { Calendar.current.isDate($0.recordDate, inSameDayAs: currentDate) }
    }
    
    private var hasAnyContent: Bool {
        !dreamsForDay.isEmpty || !reflectionsForDay.isEmpty
    }
    
    var body: some View {
        let swipeGesture = DragGesture(minimumDistance: 30)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                
                guard abs(horizontal) > abs(vertical) else { return }
                
                if horizontal < -40 {
                    shiftDay(by: 1)
                } else if horizontal > 40 {
                    shiftDay(by: -1)
                }
            }
        
        let base = AnyView(contentView)
        let withNav = AnyView(
            base
                .navigationTitle("日別の記録")
                .navigationBarTitleDisplayMode(.inline)
        )
        
        let withSheet = AnyView(
            withNav.sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .dream:
                    AddDreamView(recordDate: currentDate, dreamToEdit: dreamToEdit)
                case .reflection:
                    AddReflectionView(recordDate: currentDate, reflectionToEdit: reflectionToEdit)
                }
            }
        )
        
        let withAlert = AnyView(
            withSheet.alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        )
        
        let withDreamDialog = AnyView(
            withAlert.confirmationDialog(
                "夢を削除しますか？",
                isPresented: $showDreamDeleteConfirm
            ) {
                Button("削除", role: .destructive) {
                    if let dream = dreamPendingDelete {
                        Task { await deleteDream(dream) }
                    }
                    dreamPendingDelete = nil
                }
                Button("キャンセル", role: .cancel) {
                    dreamPendingDelete = nil
                }
            }
        )
        
        let withReflectionDialog = AnyView(
            withDreamDialog.confirmationDialog(
                "日記を削除しますか？",
                isPresented: $showReflectionDeleteConfirm
            ) {
                Button("削除", role: .destructive) {
                    if let reflection = reflectionPendingDelete {
                        Task { await deleteReflection(reflection) }
                    }
                    reflectionPendingDelete = nil
                }
                Button("キャンセル", role: .cancel) {
                    reflectionPendingDelete = nil
                }
            }
        )
        
        let withGesture = AnyView(withReflectionDialog.gesture(swipeGesture))
        
        let withDreamChange = AnyView(
            withGesture.onChange(of: dreamService.errorMessage) { _, newValue in
                if let error = newValue {
                    errorMessage = error
                    showError = true
                    dreamService.errorMessage = nil
                }
            }
        )
        
        let finalView = AnyView(
            withDreamChange.onChange(of: reflectionService.errorMessage) { _, newValue in
                if let error = newValue {
                    errorMessage = error
                    showError = true
                    reflectionService.errorMessage = nil
                }
            }
        )
        
        return finalView
    }
    
    private var contentView: some View {
        ZStack {
            Color.clear.dreamBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    
                    if hasAnyContent {
                        VStack(spacing: 16) {
                            dreamSection
                            reflectionSection
                        }
                    } else {
                        emptyState
                    }
                    
                    Spacer(minLength: 32)
                }
                .padding(.horizontal)
                .padding(.top)
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Self.dateFormatter.string(from: currentDate))
                .font(.dreamHeadline)
                .foregroundColor(.dreamText)
            Text("この日の夢と日記をまとめて確認できます。左右スワイプで日付移動。")
                .font(.dreamCaption)
                .foregroundColor(.dreamTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Button {
                    shiftDay(by: -1)
                } label: {
                    Label("前日", systemImage: "chevron.left")
                        .font(.dreamCaption)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.dreamCard)
                        .cornerRadius(12)
                }
                
                Spacer()
                
                Button {
                    shiftDay(by: 1)
                } label: {
                    Label("翌日", systemImage: "chevron.right")
                        .font(.dreamCaption)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.dreamCard)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var dreamSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "夢") {
                dreamToEdit = nil
                activeSheet = .dream
            }
            
            if dreamsForDay.isEmpty {
                Text("この日の夢の記録はありません")
                    .font(.dreamBody)
                    .foregroundColor(.dreamTextSecondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(dreamsForDay) { dream in
                        dreamCard(dream)
                    }
                }
            }
        }
    }
    
    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "日記") {
                reflectionToEdit = nil
                activeSheet = .reflection
            }
            
            if reflectionsForDay.isEmpty {
                Text("この日の日記はまだありません")
                    .font(.dreamBody)
                    .foregroundColor(.dreamTextSecondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(reflectionsForDay) { reflection in
                        reflectionCard(reflection)
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundColor(.dreamTextSecondary)
            Text("この日の記録はありません")
                .font(.dreamHeadline)
                .foregroundColor(.dreamTextSecondary)
            Text("夢や日記を追加して、この日の出来事を残しましょう。")
                .font(.dreamBody)
                .foregroundColor(.dreamTextSecondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button {
                    dreamToEdit = nil
                    activeSheet = .dream
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
                    reflectionToEdit = nil
                    activeSheet = .reflection
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
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(18)
    }
    
    private func sectionHeader(title: String, addAction: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.dreamHeadline)
                .foregroundColor(.dreamText)
            Spacer()
            Button {
                addAction()
            } label: {
                Label("\(title)を追加", systemImage: "plus.circle.fill")
                    .font(.dreamCaption)
            }
            .buttonStyle(.bordered)
            .tint(.dreamAccent)
        }
    }
    
    private func dreamCard(_ dream: Dream) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("夢の記録")
                .font(.dreamCaption)
                .foregroundColor(.dreamTextSecondary)
            
            Text(dream.content)
                .font(.dreamBody)
                .foregroundColor(.dreamText)
            
            if let interpretation = dream.interpretation {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.dreamAccent)
                        .padding(.top, 2)
                    Text(interpretation)
                        .font(.dreamCaption)
                        .foregroundColor(.dreamText.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.dreamAccent.opacity(0.2))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dreamAccent.opacity(0.3), lineWidth: 1)
                )
            } else if dreamService.interpretingDreamId == dream.id {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.dreamAccent)
                        .scaleEffect(0.8)
                    Text("夢を分析中...")
                        .font(.dreamCaption)
                        .foregroundColor(.dreamTextSecondary)
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    dreamToEdit = dream
                    activeSheet = .dream
                } label: {
                    Label("編集", systemImage: "pencil")
                        .font(.dreamCaption)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.dreamAccent)
                
                Button {
                    Task { await reinterpret(dream: dream) }
                } label: {
                    Label(dream.interpretation == nil ? "AIで占う" : "AIで再解釈", systemImage: "wand.and.stars")
                        .font(.dreamCaption)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.dreamAccent)
                .disabled(dreamService.interpretingDreamId == dream.id)
                
                Button(role: .destructive) {
                    dreamPendingDelete = dream
                    showDreamDeleteConfirm = true
                } label: {
                    Label("削除", systemImage: "trash")
                        .font(.dreamCaption)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
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
    
    private func reflectionCard(_ reflection: Reflection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("日記")
                .font(.dreamCaption)
                .foregroundColor(.dreamTextSecondary)
            
            Text(reflection.content)
                .font(.dreamBody)
                .foregroundColor(.dreamText)
            
            HStack(spacing: 12) {
                Button {
                    reflectionToEdit = reflection
                    activeSheet = .reflection
                } label: {
                    Label("追記/編集", systemImage: "square.and.pencil")
                        .font(.dreamCaption)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.dreamAccent)
                
                Button(role: .destructive) {
                    reflectionPendingDelete = reflection
                    showReflectionDeleteConfirm = true
                } label: {
                    Label("削除", systemImage: "trash")
                        .font(.dreamCaption)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
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
    
    private func shiftDay(by value: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: value, to: currentDate) else { return }
        currentDate = newDate
    }
    
    private func reinterpret(dream: Dream) async {
        guard let userId = authManager.userId else { return }
        do {
            try await dreamService.interpretDream(dream: dream, userId: userId)
        } catch { }
    }
    
    private func deleteDream(_ dream: Dream) async {
        guard let userId = authManager.userId else { return }
        do {
            try await dreamService.deleteDream(dream, userId: userId)
        } catch { }
    }
    
    private func deleteReflection(_ reflection: Reflection) async {
        guard let userId = authManager.userId else { return }
        do {
            try await reflectionService.deleteReflection(reflection, userId: userId)
        } catch { }
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()
}
