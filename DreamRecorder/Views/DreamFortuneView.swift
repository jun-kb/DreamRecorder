import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

private enum FortuneAlert: Identifiable {
    case noDream
    case missingReflection
    case overwriteInterpretation
    
    var id: String {
        switch self {
        case .noDream: return "noDream"
        case .missingReflection: return "missingReflection"
        case .overwriteInterpretation: return "overwriteInterpretation"
        }
    }
}

private enum FortuneSheet: Identifiable {
    case addDream(Date)
    case addReflection(Date)
    
    var id: String {
        switch self {
        case .addDream(let date): return "dream-\(date.timeIntervalSince1970)"
        case .addReflection(let date): return "reflection-\(date.timeIntervalSince1970)"
        }
    }
}

struct DreamFortuneView: View {
    @EnvironmentObject private var dreamService: DreamService
    @EnvironmentObject private var reflectionService: ReflectionService
    @EnvironmentObject private var authManager: AuthManager
    private let initialDate: Date?
    private let fortuneTellers = FortuneTellerManager.allFortuneTellers
    
    @State private var selectedTeller: FortuneTeller = FortuneTellerManager.allFortuneTellers.first ?? FortuneTeller(
        name: "運命の女神 ノルン",
        iconImageName: "sparkles",
        profileImageName: "sparkles",
        themeColor: .purple,
        description: "デフォルトの占い師",
        profileText: "プロフィール未設定",
        systemInstruction: ""
    )
    @State private var selectedDate: Date
    @State private var isFortuning = false
    @State private var resultText: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDatePicker = false
    @State private var tellerProfileToShow: FortuneTeller?
    @State private var fortuneAlert: FortuneAlert?
    @State private var activeSheet: FortuneSheet?
    @State private var pendingFortuneDream: Dream?
    @State private var pendingFortuneReflection: Reflection?

    init(initialDate: Date? = nil) {
        self.initialDate = initialDate
        _selectedDate = State(initialValue: initialDate ?? Date())
    }
    
    private var selectedDream: Dream? {
        dreamService.dreams.first { Calendar.current.isDate($0.recordDate, inSameDayAs: selectedDate) }
    }
    
    private var yesterdayDate: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    private var yesterdayReflection: Reflection? {
        reflectionService.reflections.first { Calendar.current.isDate($0.recordDate, inSameDayAs: yesterdayDate) }
    }
    
    private var hasDream: Bool { selectedDream != nil }
    private var hasReflection: Bool { yesterdayReflection != nil }
    private var formattedDateString: String {
        Self.monthDayWeekFormatter.string(from: selectedDate)
    }
    private var displayedResultText: String? {
        if let interpretation = selectedDream?.interpretation, !interpretation.isEmpty {
            return interpretation
        }
        return resultText.isEmpty ? nil : resultText
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.dreamBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        tellerSelector

                        dailySection
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 80)
                }
            }
            .navigationTitle("夢占い")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $tellerProfileToShow) { teller in
                profileSheet(teller)
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addDream(let date):
                    AddDreamView(recordDate: date)
                case .addReflection(let date):
                    AddReflectionView(recordDate: date)
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("夢の記録がありません", isPresented: Binding(
                get: { fortuneAlert == .noDream },
                set: { if !$0 { fortuneAlert = nil } }
            )) {
                Button("夢を記録") { activeSheet = .addDream(selectedDate) }
                Button("キャンセル", role: .cancel) { fortuneAlert = nil }
            } message: {
                Text("夢を記録してから占いを実行してください。")
            }
            .alert("昨日の日記が見つかりません。日記なしで占いますか？", isPresented: Binding(
                get: { fortuneAlert == .missingReflection },
                set: { if !$0 { fortuneAlert = nil } }
            )) {
                Button("日記なしで占う") {
                    guard let dream = pendingFortuneDream else { return }
                    // 1. まず現在のアラート状態をクリアして閉じる
                    fortuneAlert = nil
                    pendingFortuneReflection = nil
                    
                    // 【修正ポイント】
                    // アラートが完全に閉じるのを待つため、0.5秒後に次の判定を実行する
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // 2. 既に占い結果があるかチェック
                        if dream.interpretation != nil {
                            // 結果がある場合 -> 上書き確認アラートを表示
                            fortuneAlert = .overwriteInterpretation
                        } else {
                            // 結果がない場合 -> そのまま占いを開始
                            // (attemptFortuneStartの中身次第ですが、直接startFortuneを呼ぶのが確実です)
                            startFortune(dream: dream, reflection: nil)
                        }
                    }
                }
                
                Button("日記を追加") {
                    fortuneAlert = nil
                    activeSheet = .addReflection(yesterdayDate)
                }
                
                Button("キャンセル", role: .cancel) { fortuneAlert = nil }
            }
            .alert("占い結果を上書きしますか？", isPresented: Binding(
                get: { fortuneAlert == .overwriteInterpretation },
                set: { if !$0 { fortuneAlert = nil } }
            )) {
                Button("上書きして占う", role: .destructive) {
                    guard let dream = pendingFortuneDream else { return }
                    let reflection = pendingFortuneReflection
                    startFortune(dream: dream, reflection: reflection)
                }
                Button("キャンセル", role: .cancel) { fortuneAlert = nil }
            } message: {
                Text("この夢には既に占い結果があります。新しい結果で上書きしますか？")
            }
            .onChange(of: selectedDate) { _, _ in
                resultText = ""
            }
            .onChange(of: initialDate) { _, newValue in
                selectedDate = newValue ?? Date()
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
    }
    
    private var tellerSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI占い師")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundColor(.dreamText)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(fortuneTellers) { teller in
                            let isSelected = teller.id == selectedTeller.id
                            Button {
                                if isSelected {
                                    tellerProfileToShow = teller
                                } else {
                                    selectedTeller = teller
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    tellerIconView(teller)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(teller.name)
                                            .font(.system(.body, design: .rounded, weight: .semibold))
                                            .foregroundColor(.dreamText)
                                        Text(teller.description)
                                            .font(.dreamCaption)
                                            .foregroundColor(.dreamTextSecondary)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.9)
                                    }
                                    
                                    Spacer()
                                    
                                    if isSelected {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(teller.themeColor)
                                    }
                                }
                                .padding(12)
                                .frame(minWidth: 240, maxWidth: 320, alignment: .leading)
                                .background(Color.dreamCard.opacity(isSelected ? 0.9 : 0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(isSelected ? teller.themeColor.opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1.1)
                                )
                                .cornerRadius(14)
                                .shadow(color: Color.black.opacity(0.16), radius: 7, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)
                            .id(teller.id)
                        }
                    }
                }
                .onAppear { scrollToSelectedTeller(proxy) }
                .onChange(of: selectedTeller.id) { _, _ in
                    scrollToSelectedTeller(proxy)
                }
            }
        }
    }
    
    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            compactDailyHeader
            compactRecords
            actionButton
            resultContent
        }
        .padding(14)
        .background(Color.dreamCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var compactDailyHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    .onTapGesture { showDatePicker = true }
                    .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func navigationArrow(direction: Int, icon: String) -> some View {
        Button {
            shiftDate(by: direction)
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
    
    private var actionButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                handleFortune()
            } label: {
                HStack {
                    if isFortuning {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text("\(selectedTeller.name)に占ってもらう")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedTeller.themeColor.opacity(hasDream ? 0.9 : 0.5))
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: selectedTeller.themeColor.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .disabled(isFortuning)
        }
    }
    
    private var resultContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("占い結果")
                .font(.dreamBody)
                .foregroundColor(.dreamTextSecondary)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dreamCard)
                
                if let result = displayedResultText, !result.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(result)
                                .font(.dreamBody)
                                .foregroundColor(.dreamText)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 12) {
                        if isFortuning {
                            ProgressView().tint(.dreamAccent)
                            Text("占い結果を生成しています…")
                                .font(.dreamBody)
                                .foregroundColor(.dreamText)
                        } else {
                            Text("占い師を選んで、あなたの夢を占ってもらいましょう。")
                                .font(.dreamBody)
                                .foregroundColor(.dreamTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .frame(minHeight: 170, maxHeight: 260)
        }
    }

    private var compactRecords: some View {
        VStack(spacing: 10) {
            if let dream = selectedDream {
                NavigationLink {
                    DailyDetailView(date: dream.recordDate)
                } label: {
                    FortuneCompactRow(title: "今日の夢", content: dream.content)
                }
                .buttonStyle(.plain)
            } else {
                FortuneAddPromptRow(title: "今日の夢", prompt: "夢を追加しましょう", icon: "moon.zzz") {
                    activeSheet = .addDream(selectedDate)
                }
                .buttonStyle(.plain)
            }

            if let reflection = yesterdayReflection {
                NavigationLink {
                    DailyDetailView(date: reflection.recordDate)
                } label: {
                    FortuneCompactRow(title: "昨日の日記", content: reflection.content)
                }
                .buttonStyle(.plain)
            } else {
                FortuneAddPromptRow(title: "昨日の日記", prompt: "日記を追加しましょう", icon: "square.and.pencil") {
                    activeSheet = .addReflection(yesterdayDate)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private struct FortuneCompactRow: View {
        let title: String
        let content: String
        var body: some View {
            HStack(spacing: 10) {
                FortuneRowBadge(title: title)
                Text(content)
                    .font(.dreamBody)
                    .foregroundColor(.dreamText)
                    .lineLimit(1)
                Spacer()
                FortuneNavigationArrow()
            }
            .padding(12)
            .background(Color.dreamCard.opacity(0.9))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private struct FortuneRowBadge: View {
        let title: String
        var body: some View {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.dreamAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.dreamAccent.opacity(0.16))
                .cornerRadius(10)
        }
    }

    private struct FortuneNavigationArrow: View {
        var body: some View {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.dreamAccent)
                .padding(8)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }

    private struct FortuneAddPromptRow: View {
        let title: String
        let prompt: String
        let icon: String
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.dreamAccent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.dreamAccent)
                        Text(prompt)
                            .font(.dreamCaption)
                            .foregroundColor(.dreamTextSecondary)
                    }
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.dreamTextSecondary.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.dreamCard.opacity(0.3))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundColor(.dreamAccent.opacity(0.4))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Fortune Teller Images

    private func tellerIconView(_ teller: FortuneTeller) -> some View {
        Group {
            if let image = assetImage(named: teller.iconImageName) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .foregroundColor(teller.themeColor)
            }
        }
        .frame(width: 42, height: 42)
        .background(teller.themeColor.opacity(0.12))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(teller.themeColor.opacity(0.35), lineWidth: 1)
        )
    }

    private func tellerProfileImageView(_ teller: FortuneTeller) -> some View {
        ZStack {
            if let image = assetImage(named: teller.profileImageName) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 260) // 顔が切れにくいよう上側を優先
                    .clipped()
            } else {
                LinearGradient(
                    colors: [teller.themeColor.opacity(0.45), Color.black.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(alignment: .leading, spacing: 8) {
                    Text("プロフィール画像を追加してください")
                        .font(.dreamBody)
                        .foregroundColor(.white.opacity(0.9))
                    Text(teller.name)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
    }

    private func assetImage(named name: String) -> Image? {
        #if canImport(UIKit)
        if let uiImage = UIImage(named: name) {
            return Image(uiImage: uiImage)
        }
        #elseif canImport(AppKit)
        if let nsImage = NSImage(named: name) {
            return Image(nsImage: nsImage)
        }
        #endif
        return nil
    }
    
    private func shiftDate(by value: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: value, to: selectedDate) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedDate = newDate
        }
    }

    private func scrollToSelectedTeller(_ proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            proxy.scrollTo(selectedTeller.id, anchor: .center)
        }
    }
    
    private func handleFortune() {
        guard let dream = selectedDream else {
            pendingFortuneDream = nil
            fortuneAlert = .noDream
            return
        }
        pendingFortuneDream = dream
        pendingFortuneReflection = yesterdayReflection
        if let reflection = yesterdayReflection {
            attemptFortuneStart(dream: dream, reflection: reflection)
        } else {
            fortuneAlert = .missingReflection
        }
    }

    private func attemptFortuneStart(dream: Dream, reflection: Reflection?) {
        pendingFortuneDream = dream
        pendingFortuneReflection = reflection
        if let interpretation = dream.interpretation, !interpretation.isEmpty {
            fortuneAlert = .overwriteInterpretation
            return
        }
        startFortune(dream: dream, reflection: reflection)
    }
    
    private func startFortune(dream: Dream, reflection: Reflection?) {
        guard let userId = authManager.userId, !userId.isEmpty else {
            let error = AppError.authenticationRequired
            ErrorLogger.logError(error, context: "DreamFortuneView.startFortune")
            errorMessage = ErrorLogger.userFacingMessage(from: error)
            showError = true
            return
        }

        isFortuning = true
        errorMessage = ""
        resultText = ""
        
        Task {
            do {
                try await dreamService.interpretDream(
                    dream: dream,
                    reflection: reflection,
                    teller: selectedTeller,
                    userId: userId
                )
                await MainActor.run {
                    isFortuning = false
                }
            } catch {
                let appError = ErrorLogger.classify(error, context: .ai)
                ErrorLogger.logError(appError, context: "DreamFortuneView.handleFortune")
                await MainActor.run {
                    errorMessage = ErrorLogger.userFacingMessage(from: appError)
                    showError = true
                    isFortuning = false
                }
            }
        }
    }
    
    private func profileSheet(_ teller: FortuneTeller) -> some View {
        NavigationStack {
            ZStack {
                Color.clear.dreamBackground()
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    tellerProfileImageView(teller)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(teller.name)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundColor(.dreamText)
                    }
                    
                    Text(teller.description)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.dreamText)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { tellerProfileToShow = nil }
                        .foregroundColor(.dreamAccent)
                }
            }
        }
    }
    
    private var datePickerSheet: some View {
        NavigationStack {
            ZStack {
                Color.clear.dreamBackground()
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker(
                        "日付を選択",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(.dreamAccent)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("日付を選ぶ")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { showDatePicker = false }
                        .foregroundColor(.dreamAccent)
                }
            }
        }
    }
    
    private static let monthDayWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）"
        return formatter
    }()
}

