import SwiftUI
import UIKit

private enum SlideDirection {
    case forward
    case backward
}

private struct SheetContext: Identifiable {
    let id = UUID()
    let type: SheetType
}

private enum SheetType {
    case dream(Dream?)
    case reflection(Reflection?)
}

private enum SwipeThreshold {
    static let minimumDistance: CGFloat = 30
    static let triggerDistance: CGFloat = 40
}

struct DailyDetailView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var reflectionService: ReflectionService
    @EnvironmentObject var authManager: AuthManager
    
    let date: Date
    
    @State private var sheetContext: SheetContext?
    @State private var dreamPendingDelete: Dream?
    @State private var reflectionPendingDelete: Reflection?
    @State private var showDreamDeleteConfirm = false
    @State private var showReflectionDeleteConfirm = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var currentDate: Date
    @State private var slideDirection: SlideDirection = .forward
    @State private var interpretationToShow: String?
    
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        feedbackSelection()
                        openDreamSheet(editing: nil)
                    } label: {
                        Label("夢を追加", systemImage: "plus.circle")
                    }
                    
                    Button {
                        feedbackSelection()
                        openReflectionSheet(editing: nil)
                    } label: {
                        Label("日記を追加", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.dreamAccent)
                }
            }
        }
        .sheet(item: $sheetContext) { context in
            switch context.type {
            case .dream(let target):
                AddDreamView(recordDate: currentDate, dreamToEdit: target)
                    .id(context.id)
            case .reflection(let target):
                AddReflectionView(recordDate: currentDate, reflectionToEdit: target)
                    .id(context.id)
            }
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: Binding(get: { interpretationToShow != nil }, set: { if !$0 { interpretationToShow = nil } })) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("AI占い結果")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(.dreamText)
                    Spacer()
                    Button("閉じる") { interpretationToShow = nil }
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .foregroundColor(.dreamAccent)
                }
                
                ScrollView {
                    Text(interpretationToShow ?? "")
                        .font(.system(.callout, design: .rounded))
                        .foregroundColor(.dreamText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .background(Color.clear.dreamBackground().ignoresSafeArea())
        }
        .confirmationDialog(
            "夢を削除しますか？",
            isPresented: $showDreamDeleteConfirm,
            titleVisibility: .visible
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
        } message: {
            Text("この操作は取り消せません。")
        }
        .confirmationDialog(
            "日記を削除しますか？",
            isPresented: $showReflectionDeleteConfirm,
            titleVisibility: .visible
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
        } message: {
            Text("この操作は取り消せません。")
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
        DragGesture(minimumDistance: SwipeThreshold.minimumDistance)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                
                guard abs(horizontal) > abs(vertical) else { return }
                
                if horizontal < -SwipeThreshold.triggerDistance {
                    shiftDay(by: 1)
                } else if horizontal > SwipeThreshold.triggerDistance {
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
            if dreamsForDay.isEmpty {
                HStack {
                    Text("夢")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundColor(.dreamText)
                    Spacer()
                    Button {
                        openDreamSheet(editing: nil)
                    } label: {
                        Label("夢を追加", systemImage: "plus.circle.fill")
                            .font(.system(.callout, design: .rounded, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.dreamAccent)
                }
                
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
            if reflectionsForDay.isEmpty {
                HStack {
                    Text("日記")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundColor(.dreamText)
                    Spacer()
                    Button {
                        feedbackSelection()
                        openReflectionSheet(editing: nil)
                    } label: {
                        Label("日記を追加", systemImage: "plus.circle.fill")
                            .font(.system(.callout, design: .rounded, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.dreamAccent)
                }
                
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
                    feedbackSelection()
                    openDreamSheet(editing: nil)
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
                    feedbackSelection()
                    openReflectionSheet(editing: nil)
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
    
    private func dreamCard(_ dream: Dream) -> some View {
        let isInterpreting = dreamService.interpretingDreamId == dream.id
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("夢")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.dreamAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.dreamAccent.opacity(0.18))
                    .cornerRadius(12)
                
                Spacer()
                
                HStack(spacing: 10) {
                    Button {
                        Task { await reinterpret(dream: dream) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text(dream.interpretation == nil ? "AI占い" : "再解釈")
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.dreamAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.dreamAccent.opacity(0.18))
                        .cornerRadius(14)
                    }
                    .disabled(isInterpreting)

                    Menu {
                        Button {
                            feedbackSelection()
                            openDreamSheet(editing: dream)
                        } label: {
                            Label("編集", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            feedbackSelection()
                            dreamPendingDelete = dream
                            showDreamDeleteConfirm = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.dreamText)
                    }
                }
            }
            
            if isInterpreting {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.dreamAccent)
                        .scaleEffect(0.8)
                    Text("占い中...")
                        .font(.dreamCaption)
                        .foregroundColor(.dreamAccent)
                }
                .padding(.vertical, 6)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isInterpreting)
            }
            
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
                        .font(.system(.callout, design: .rounded))
                        .foregroundColor(.dreamText.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                        .onTapGesture {
                            interpretationToShow = interpretation
                        }
                }
                .padding(12)
                        .background(Color.dreamAccent.opacity(0.2))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.dreamAccent.opacity(0.3), lineWidth: 1)
                        )
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("日記")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.dreamAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.dreamAccent.opacity(0.18))
                    .cornerRadius(12)
                
                Spacer()
                
                Menu {
                    Button {
                        feedbackSelection()
                        openReflectionSheet(editing: reflection)
                    } label: {
                        Label("編集", systemImage: "square.and.pencil")
                    }
                    
                    Button(role: .destructive) {
                        feedbackSelection()
                        reflectionPendingDelete = reflection
                        showReflectionDeleteConfirm = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.dreamText)
                }
            }
            
            Text(reflection.content)
                .font(.dreamBody)
                .foregroundColor(.dreamText)
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
    
    private func feedbackSelection() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func openDreamSheet(editing dream: Dream?) {
        sheetContext = SheetContext(type: .dream(dream))
    }
    
    private func openReflectionSheet(editing reflection: Reflection?) {
        sheetContext = SheetContext(type: .reflection(reflection))
    }
    
    private func reinterpret(dream: Dream) async {
        guard let userId = authManager.userId else { return }
        do {
            try await dreamService.interpretDream(dream: dream, userId: userId)
        } catch {
            let appError = ErrorLogger.classify(error, context: .ai)
            ErrorLogger.logError(appError, context: "DailyDetailView.reinterpret")
            await MainActor.run {
                errorMessage = ErrorLogger.userFacingMessage(from: appError)
                showError = true
            }
        }
    }
    
    private func deleteDream(_ dream: Dream) async {
        guard let userId = authManager.userId else { return }
        do {
            try await dreamService.deleteDream(dream, userId: userId)
        } catch {
            let appError = ErrorLogger.classify(error, context: .network)
            ErrorLogger.logError(appError, context: "DailyDetailView.deleteDream")
            await MainActor.run {
                errorMessage = ErrorLogger.userFacingMessage(from: appError)
                showError = true
            }
        }
    }
    
    private func deleteReflection(_ reflection: Reflection) async {
        guard let userId = authManager.userId else { return }
        do {
            try await reflectionService.deleteReflection(reflection, userId: userId)
        } catch {
            let appError = ErrorLogger.classify(error, context: .network)
            ErrorLogger.logError(appError, context: "DailyDetailView.deleteReflection")
            await MainActor.run {
                errorMessage = ErrorLogger.userFacingMessage(from: appError)
                showError = true
            }
        }
    }
    
    private static let monthDayWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d|EEE"
        return formatter
    }()
}
