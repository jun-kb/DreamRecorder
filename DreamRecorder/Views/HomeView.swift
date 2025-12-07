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
    
    @State private var activeSheet: AddSheet?
    @State private var dreamToEdit: Dream?
    @State private var reflectionToEdit: Reflection?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var navigateToDailyDetail = false
    @State private var detailDate: Date = Date()
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    
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
                    calendarSection
                    
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
                                    Section(header: EmptyView()) {
                                        ForEach(filteredDreams) { dream in
                                            Button {
                                                detailDate = dream.recordDate
                                                navigateToDailyDetail = true
                                            } label: {
                                                CompactDreamRow(dream: dream)
                                            }
                                            .buttonStyle(.plain)
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        }
                                        .onDelete(perform: deleteDreams)
                                    }
                                }
                                
                                if !filteredReflections.isEmpty {
                                    Section(header: EmptyView()) {
                                        ForEach(filteredReflections) { reflection in
                                            Button {
                                                detailDate = reflection.recordDate
                                                navigateToDailyDetail = true
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
                    Menu {
                        Button {
                            self.dreamToEdit = nil
                            self.activeSheet = .dream
                        } label: {
                            Label("夢を追加", systemImage: "plus.circle")
                        }
                        
                        Button {
                            self.reflectionToEdit = nil
                            self.activeSheet = .reflection
                        } label: {
                            Label("日記を追加", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.dreamAccent)
                    }
                }
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
                    let appError = ErrorLogger.classify(error, context: .network)
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
                    let appError = ErrorLogger.classify(error, context: .network)
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

// MARK: - Calendar
private extension HomeView {
    var calendarSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shiftMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.dreamAccent)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                Spacer()
                Text(Self.monthFormatter.string(from: displayedMonth))
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.dreamText)
                Spacer()
                Button { shiftMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.dreamAccent)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            
            HStack {
                ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.dreamCaption)
                        .foregroundColor(.dreamTextSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 10)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(monthDaysWithPadding.indices, id: \.self) { index in
                    if let date = monthDaysWithPadding[index] {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
        .padding()
    }
    
    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        
        return Button {
            if isSelected {
                detailDate = date
                navigateToDailyDetail = true
            } else {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 4) {
                Text(Self.dayFormatter.string(from: date))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .black : .dreamText)
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.dreamAccent : Color.clear)
                    )
                if isToday && !isSelected {
                    Circle()
                        .fill(Color.dreamAccent)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 40)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.dreamAccent.opacity(0.15) : Color.white.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var monthDaysWithPadding: [Date?] {
        let start = calendar.startOfMonth(for: displayedMonth)
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        
        let firstWeekday = calendar.component(.weekday, from: start)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
        
        var padded: [Date?] = Array(repeating: nil, count: offset)
        padded.append(contentsOf: days)
        
        let remainder = padded.count % 7
        if remainder != 0 {
            padded.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }
        return padded
    }
    
    private func shiftMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = newMonth
    }
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d"
        return formatter
    }()
    
    private static let weekdaySymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.shortWeekdaySymbols.map { $0.uppercased() }
    }()
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

// コンパクト表示用の行（1行のみ表示）
private struct CompactDreamRow: View {
    let dream: Dream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("夢")
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
            
            Text(dream.content)
                .font(.dreamBody)
                .foregroundColor(.dreamText)
                .lineLimit(1)
            
            HStack {
                Text(dream.recordDate, style: .date)
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

private struct CompactReflectionRow: View {
    let reflection: Reflection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("日記")
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
            
            Text(reflection.content)
                .font(.dreamBody)
                .foregroundColor(.dreamText)
                .lineLimit(1)
            
            HStack {
                Text(reflection.recordDate, style: .date)
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
