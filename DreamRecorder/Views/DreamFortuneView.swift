import SwiftUI

private enum AnalysisSource: String, CaseIterable, Identifiable {
    case dreamOnly = "夢のみで占う"
    case dreamAndReflection = "夢と日記で占う"
    
    var id: String { rawValue }
}

private enum FortuneAlert: Identifiable {
    case noDream
    case missingReflection
    
    var id: String {
        switch self {
        case .noDream: return "noDream"
        case .missingReflection: return "missingReflection"
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
    @Namespace private var tellerNamespace
    private let fortuneTellers = FortuneTellerManager.allFortuneTellers
    
    @State private var selectedTeller: FortuneTeller = FortuneTellerManager.allFortuneTellers.first ?? FortuneTeller(
        name: "運命の女神 ノルン",
        imageName: "sparkles",
        themeColor: .purple,
        description: "デフォルトの占い師",
        systemInstruction: ""
    )
    @State private var source: AnalysisSource = .dreamOnly
    @State private var selectedDate: Date = Date()
    @State private var isFortuning = false
    @State private var resultText: String = ""
    @State private var errorMessage: String?
    @State private var showDatePicker = false
    @State private var tellerProfileToShow: FortuneTeller?
    @State private var fortuneAlert: FortuneAlert?
    @State private var activeSheet: FortuneSheet?
    @State private var pendingFortuneDream: Dream?
    
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
    private var dateLabel: String { Self.dateFormatter.string(from: selectedDate) }
    private var formattedDateString: String {
        let dateString = Self.monthDayWeekFormatter.string(from: selectedDate)
        let components = dateString.split(separator: "|").map(String.init)
        guard components.count == 2 else { return dateString }
        let weekdayUpper = components[1].uppercased()
        return "\(components[0]), \(weekdayUpper)"
    }
    private var displayedResultText: String? {
        if let interpretation = selectedDream?.interpretation, !interpretation.isEmpty {
            return interpretation
        }
        return resultText.isEmpty ? nil : resultText
    }
    
    var body: some View {
        ZStack {
            Color.clear.dreamBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    selectedTellerCard
                    tellerSelector

                    dailySection
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
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
        .alert("エラー", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(item: $fortuneAlert) { alert in
            switch alert {
            case .noDream:
                Alert(
                    title: Text("夢の記録がありません"),
                    dismissButton: .default(Text("OK")) {
                        activeSheet = .addDream(selectedDate)
                    }
                )
            case .missingReflection:
                Alert(
                    title: Text("昨日の日記が見つかりません。日記なしで占いますか？"),
                    primaryButton: .default(Text("日記なしで占う")) {
                        guard let dream = pendingFortuneDream else { return }
                        startFortune(dream: dream, reflection: nil)
                    },
                    secondaryButton: .default(Text("日記を追加")) {
                        activeSheet = .addReflection(yesterdayDate)
                    }
                )
            }
        }
        .onChange(of: selectedDate) { _, _ in
            if source == .dreamAndReflection && !hasReflection {
                source = .dreamOnly
            }
            resultText = ""
        }
    }
    
    private var tellerSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI占い師")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundColor(.dreamText)
            
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
                                Image(systemName: teller.imageName)
                                    .font(.system(size: 20, weight: .bold))
                                    .frame(width: 42, height: 42)
                                    .foregroundColor(teller.themeColor)
                                    .background(teller.themeColor.opacity(0.15))
                                    .clipShape(Circle())
                                
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
                    }
                }
            }
        }
    }

    private var selectedTellerCard: some View {
        let teller = selectedTeller
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.dreamCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: teller.themeColor.opacity(0.2), radius: 14, x: 0, y: 8)
                .matchedGeometryEffect(id: "teller_\(teller.id)", in: tellerNamespace)

            HStack(alignment: .center, spacing: 14) {
                Image(systemName: teller.imageName)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(teller.themeColor)
                    .frame(width: 70, height: 70)
                    .background(teller.themeColor.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(teller.name)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundColor(.dreamText)
                    Text(teller.description)
                        .font(.dreamCaption)
                        .foregroundColor(.dreamTextSecondary)
                        .lineLimit(3)
                }

                Spacer()
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            compactDailyHeader
            sourcePicker
            actionButton
            if let result = displayedResultText, !result.isEmpty {
                resultCard(result)
            }
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
                    .animation(.easeInOut(duration: 0.2), value: selectedDate)
                
                HStack {
                    navigationArrow(direction: -1, icon: "chevron.left")
                    Spacer()
                    navigationArrow(direction: 1, icon: "chevron.right")
                }
                .padding(.horizontal, 14)
                
                Text(formattedDateString)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.dreamText)
                    .padding(.horizontal, 64)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .onTapGesture { showDatePicker = true }
                    .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity)
            
            HStack(spacing: 8) {
                statusBadge(label: "夢", isDone: hasDream)
                statusBadge(label: "前日の日記", isDone: hasReflection)
            }
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
    
    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("分析ソース")
                .font(.dreamBody)
                .foregroundColor(.dreamTextSecondary)
            
            Picker("分析ソース", selection: $source) {
                Text("夢のみで占う").tag(AnalysisSource.dreamOnly)
                Text("夢と日記で占う").tag(AnalysisSource.dreamAndReflection)
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 2)
            .onChange(of: source) { _, newValue in
                if newValue == .dreamAndReflection && !hasReflection {
                    source = .dreamOnly
                }
            }
            
            if source == .dreamAndReflection && !hasReflection {
                Text("前日の日記の記録が必要です")
                    .font(.dreamCaption)
                    .foregroundColor(.orange)
            }
        }
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
            
            if !hasDream {
                Text("選択した日に夢の記録がありません")
                    .font(.dreamCaption)
                    .foregroundColor(.orange)
            } else if source == .dreamAndReflection && !hasReflection {
                Text("前日の日記がないため、夢のみで占います")
                    .font(.dreamCaption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private func resultCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("占い結果")
                .font(.dreamBody)
                .foregroundColor(.dreamTextSecondary)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dreamCard)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(text)
                            .font(.dreamBody)
                            .foregroundColor(.dreamText)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                }
            }
            .frame(minHeight: 180, maxHeight: 260)
        }
    }
    
    private func statusBadge(label: String, isDone: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isDone ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isDone ? .green : .orange)
            Text(label + (isDone ? "あり" : "なし"))
                .font(.dreamCaption)
                .foregroundColor(.dreamText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func shiftDate(by value: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: value, to: selectedDate) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDate = newDate
        }
    }
    
    private func handleFortune() {
        guard let dream = selectedDream else {
            pendingFortuneDream = nil
            fortuneAlert = .noDream
            return
        }
        pendingFortuneDream = dream
        if let reflection = yesterdayReflection {
            startFortune(dream: dream, reflection: reflection)
        } else {
            fortuneAlert = .missingReflection
        }
    }
    
    private func startFortune(dream: Dream, reflection: Reflection?) {
        guard let userId = authManager.userId, !userId.isEmpty else {
            errorMessage = "サインインすると占いが利用できます"
            return
        }

        isFortuning = true
        errorMessage = nil
        resultText = ""
        source = reflection == nil ? .dreamOnly : .dreamAndReflection
        
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
                    HStack(spacing: 12) {
                        Image(systemName: teller.imageName)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(teller.themeColor)
                            .frame(width: 52, height: 52)
                            .background(teller.themeColor.opacity(0.15))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 6) {
                            Text(teller.name)
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundColor(.dreamText)
                            Text(teller.description)
                                .font(.dreamBody)
                                .foregroundColor(.dreamTextSecondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Text(teller.systemInstruction)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.dreamText)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("占い師プロフィール")
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
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "y年M月d日"
        return formatter
    }()
    
    private static let monthDayWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日|E"
        return formatter
    }()
}

