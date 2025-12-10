import SwiftUI

private enum AnalysisTab: String, CaseIterable, Identifiable {
    case daily = "今日の占い"
    case longTerm = "長期分析"
    
    var id: String { rawValue }
}

private enum AnalysisSource: String, CaseIterable, Identifiable {
    case dreamOnly = "夢のみで占う"
    case dreamAndReflection = "夢と日記で占う"
    
    var id: String { rawValue }
}

private enum FortuneTeller: CaseIterable, Identifiable {
    case luna
    case leo
    
    var id: String { name }
    
    var name: String {
        switch self {
        case .luna: return "ルナ"
        case .leo: return "レオ"
        }
    }
    
    var title: String {
        switch self {
        case .luna: return "月明かりの癒やし手"
        case .leo: return "情熱の導き手"
        }
    }
    
    var icon: String {
        switch self {
        case .luna: return "moon.stars.fill"
        case .leo: return "sun.max.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .luna: return Color.dreamAccent
        case .leo: return Color.orange
        }
    }
    
    var tagline: String {
        switch self {
        case .luna: return "穏やかに寄り添うヒーラー"
        case .leo: return "背中を押すコーチ"
        }
    }
    
    var detailDescription: String {
        switch self {
        case .luna:
            return "静かな月光のように心を落ち着かせ、感情を受け止めながら優しく導きます。内省・癒やしが欲しい時におすすめ。"
        case .leo:
            return "太陽のエネルギーで背中を押し、行動や決断を後押しする情熱系の占い師。前に進みたい時におすすめ。"
        }
    }
}

struct AIAnalysisView: View {
    @EnvironmentObject private var dreamService: DreamService
    @EnvironmentObject private var reflectionService: ReflectionService
    
    @State private var selectedTeller: FortuneTeller = .luna
    @State private var selectedTab: AnalysisTab = .daily
    @State private var source: AnalysisSource = .dreamOnly
    @State private var selectedDate: Date = Date()
    @State private var isLoading = false
    @State private var resultText: String = ""
    @State private var errorMessage: String?
    @State private var showDatePicker = false
    @State private var tellerProfileToShow: FortuneTeller?
    
    private var selectedDream: Dream? {
        dreamService.dreams.first { Calendar.current.isDate($0.recordDate, inSameDayAs: selectedDate) }
    }
    
    private var selectedReflection: Reflection? {
        reflectionService.reflections.first { Calendar.current.isDate($0.recordDate, inSameDayAs: selectedDate) }
    }
    
    private var hasDream: Bool { selectedDream != nil }
    private var hasReflection: Bool { selectedReflection != nil }
    private var dateLabel: String { Self.dateFormatter.string(from: selectedDate) }
    
    var body: some View {
        ZStack {
            Color.clear.dreamBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    
                    tellerSelector
                    
                    Picker("モード", selection: $selectedTab) {
                        ForEach(AnalysisTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Group {
                        switch selectedTab {
                        case .daily:
                            dailySection
                        case .longTerm:
                            longTermPlaceholder
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("AI分析")
        .sheet(item: $tellerProfileToShow) { teller in
            profileSheet(teller)
        }
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
        .alert("エラー", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: selectedDate) { _ in
            if source == .dreamAndReflection && !hasReflection {
                source = .dreamOnly
            }
            resultText = ""
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AI占い師を選んで分析")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundColor(.dreamText)
            Text("占い師を選んで、日付を動かしながら占いを楽しめます。")
                .font(.dreamCaption)
                .foregroundColor(.dreamTextSecondary)
        }
    }
    
    private var tellerSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI占い師")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundColor(.dreamText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FortuneTeller.allCases) { teller in
                        Button {
                            if teller == selectedTeller {
                                tellerProfileToShow = teller
                            } else {
                                selectedTeller = teller
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: teller.icon)
                                    .font(.system(size: 20, weight: .bold))
                                    .frame(width: 42, height: 42)
                                    .foregroundColor(teller.color)
                                    .background(teller.color.opacity(0.15))
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(teller.name)
                                        .font(.system(.body, design: .rounded, weight: .semibold))
                                        .foregroundColor(.dreamText)
                                    Text(teller.tagline)
                                        .font(.dreamCaption)
                                        .foregroundColor(.dreamTextSecondary)
                                }
                                
                                Spacer()
                                
                                if teller == selectedTeller {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(teller.color)
                                }
                            }
                            .padding(12)
                            .frame(width: 250, alignment: .leading)
                            .background(Color.dreamCard.opacity(teller == selectedTeller ? 0.9 : 0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(teller == selectedTeller ? teller.color.opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1.1)
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
    
    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            compactDailyHeader
            sourcePicker
            actionButton
            resultCard
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今日の占い")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.dreamText)
                Spacer(minLength: 8)
                Button {
                    showDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.dreamAccent)
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 10) {
                Button {
                    shiftDate(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.dreamAccent)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Text(dateLabel)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(.dreamText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                
                Button {
                    shiftDate(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.dreamAccent)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 8) {
                statusBadge(label: "夢", isDone: hasDream)
                statusBadge(label: "日記", isDone: hasReflection)
            }
        }
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
            .onChange(of: source) { newValue in
                if newValue == .dreamAndReflection && !hasReflection {
                    source = .dreamOnly
                }
            }
            
            if source == .dreamAndReflection && !hasReflection {
                Text("日記の記録が必要です")
                    .font(.dreamCaption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var actionButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                runDailyAnalysis()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text("\(selectedTeller.name)に占ってもらう")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedTeller.color.opacity(hasDream ? 0.9 : 0.5))
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: selectedTeller.color.opacity(0.3), radius: 10, x: 0, y: 6)
            }
            .disabled(isLoading || !hasDream || (source == .dreamAndReflection && !hasReflection))
            
            if !hasDream {
                Text("選択した日に夢の記録がありません")
                    .font(.dreamCaption)
                    .foregroundColor(.orange)
            } else if source == .dreamAndReflection && !hasReflection {
                Text("日記がないため、夢のみで占います")
                    .font(.dreamCaption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("占い結果")
                .font(.dreamBody)
                .foregroundColor(.dreamTextSecondary)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if resultText.isEmpty {
                            Text("占い結果がここに表示されます。")
                                .font(.dreamCaption)
                                .foregroundColor(.dreamTextSecondary)
                        } else {
                            Text(resultText)
                                .font(.system(.callout, design: .rounded))
                                .foregroundColor(.dreamText)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding()
                }
            }
            .frame(minHeight: 180, maxHeight: 260)
        }
    }
    
    private var longTermPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("長期分析")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundColor(.dreamText)
            Text("近日対応予定です。過去の夢の傾向を6属性で分析し、\(selectedTeller.name) がアドバイスします。")
                .font(.dreamBody)
                .foregroundColor(.dreamTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dreamCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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
        selectedDate = newDate
    }
    
    private func runDailyAnalysis() {
        guard let dream = selectedDream else {
            errorMessage = "選択した日に夢の記録がありません。"
            return
        }
        if source == .dreamAndReflection && !hasReflection {
            errorMessage = "日記の記録が必要です。"
            return
        }
        
        isLoading = true
        errorMessage = nil
        resultText = ""
        
        Task {
            // Mock async processing
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let base = source == .dreamAndReflection ? "夢と日記を合わせて" : "夢だけをもとに"
            let summary = selectedReflection?.content.prefix(40) ?? ""
            let snippet = dream.content.prefix(40)
            let composed = """
            \(base) \(selectedTeller.title)の\(selectedTeller.name)が優しく分析しました。
            夢のポイント: \(snippet)
            \(source == .dreamAndReflection ? "日記の気づき: \(summary)" : "")
            きょうは肩の力を抜きつつ、小さな行動から始めると良さそうです。
            """
            await MainActor.run {
                resultText = composed.trimmingCharacters(in: .whitespacesAndNewlines)
                isLoading = false
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
                        Image(systemName: teller.icon)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(teller.color)
                            .frame(width: 52, height: 52)
                            .background(teller.color.opacity(0.15))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 6) {
                            Text(teller.name)
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundColor(.dreamText)
                            Text(teller.title)
                                .font(.dreamBody)
                                .foregroundColor(.dreamTextSecondary)
                        }
                    }
                    
                    Text(teller.detailDescription)
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
}
