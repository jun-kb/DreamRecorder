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

private enum SlideDirection {
    case forward
    case backward
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
    @State private var slideDirection: SlideDirection = .forward
    
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
        ZStack {
            Color.clear.dreamBackground()
                .ignoresSafeArea()
            
            ZStack {
                contentView
                    .id(currentDate)
                    .transition(transition(for: slideDirection))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .dream:
                AddDreamView(recordDate: currentDate, dreamToEdit: dreamToEdit)
            case .reflection:
                AddReflectionView(recordDate: currentDate, reflectionToEdit: reflectionToEdit)
            }
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog(
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
        .confirmationDialog(
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
        .gesture(swipeGesture)
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
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
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
    }
    
    private var contentView: some View {
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
    
    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
                
                HStack {
                    navigationArrow(direction: -1, icon: "chevron.left")
                    Spacer()
                    navigationArrow(direction: 1, icon: "chevron.right")
                }
                .padding(.horizontal, 14)
                
                Text(formattedDateString)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundColor(.dreamText)
                    .padding(.horizontal, 64)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func navigationArrow(direction: Int, icon: String) -> some View {
        Button {
            shiftDay(by: direction)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.dreamAccent)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var formattedDateString: String {
        let dateString = Self.monthDayWeekFormatter.string(from: currentDate)
        let components = dateString.split(separator: "|").map(String.init)
        guard components.count == 2 else { return dateString }
        
        let weekdayUpper = components[1].uppercased()
        return "\(components[0]), \(weekdayUpper)"
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
    
    private func transition(for direction: SlideDirection) -> AnyTransition {
        switch direction {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
        }
    }
    
    private func shiftDay(by value: Int) {
        guard value != 0 else { return }
        slideDirection = value > 0 ? .forward : .backward
        guard let newDate = Calendar.current.date(byAdding: .day, value: value, to: currentDate) else { return }
        
        withAnimation(.easeInOut(duration: 0.25)) {
            currentDate = newDate
        }
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
    
    private static let monthDayWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d|EEE"
        return formatter
    }()
}
