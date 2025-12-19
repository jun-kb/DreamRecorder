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

private struct CoreParameters {
    var emotion: Double
    var action: Double
    var social: Double
    var fantasy: Double
    var chaos: Double
    var lucidity: Double
    
    var asArray: [Double] { [emotion, action, social, fantasy, chaos, lucidity] }
    
    static var mockCurrent: CoreParameters {
        CoreParameters(emotion: 0.68, action: 0.55, social: 0.48, fantasy: 0.71, chaos: 0.42, lucidity: 0.64)
    }
    
    static var mockPrevious: CoreParameters {
        CoreParameters(emotion: 0.52, action: 0.61, social: 0.45, fantasy: 0.58, chaos: 0.54, lucidity: 0.59)
    }
}

private struct DreamAnalysisData {
    var current: CoreParameters
    var previous: CoreParameters
    var advice: String
    
    static var mock: DreamAnalysisData {
        DreamAnalysisData(
            current: .mockCurrent,
            previous: .mockPrevious,
            advice: "今月は静かな創造力が高まりつつあります。感情と覚醒のバランスを保ちながら、少しだけ行動を増やすと輝きが強くなりそうです。"
        )
    }
}

private struct FortuneTellerConfig {
    let labels: [String]
    let color: Color
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
            return "静かな月光のように心を落ち着かせ、感情を受け止めながら優しく導きます。内省や癒やしを深めたい時におすすめ。"
        case .leo:
            return "太陽のエネルギーで背中を押し、行動や決断を後押しする情熱系の占い師。踏み出す勇気や勢いが欲しい時におすすめ。"
        }
    }
    
    var config: FortuneTellerConfig {
        switch self {
        case .leo:
            return FortuneTellerConfig(
                labels: ["情熱", "勇気", "仲間", "魔力", "試練", "覚醒"],
                color: .orange
            )
        case .luna:
            return FortuneTellerConfig(
                labels: ["平穏", "活動", "絆", "創造", "ストレス", "気づき"],
                color: .dreamAccent
            )
        }
    }
}

private struct AttributeDetail: Identifiable {
    let id = UUID()
    let attribute: String
    let message: String
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
    @State private var showComparison = false
    @State private var analysisData: DreamAnalysisData = .mock
    @State private var attributeDetail: AttributeDetail?
    
    private var selectedDream: Dream? {
        dreamService.dreams.first { Calendar.current.isDate($0.recordDate, inSameDayAs: selectedDate) }
    }
    
    private var selectedReflection: Reflection? {
        reflectionService.reflections.first { Calendar.current.isDate($0.recordDate, inSameDayAs: selectedDate) }
    }
    
    private var hasDream: Bool { selectedDream != nil }
    private var hasReflection: Bool { selectedReflection != nil }
    private var dateLabel: String { Self.dateFormatter.string(from: selectedDate) }
    private var attributeLabels: [String] { selectedTeller.config.labels }
    private var attributeMeanings: [String] {
        [
            "感情の深さや共感、心の動きを映す軸です。",
            "行動力や前進の勢いを示す軸です。",
            "人とのつながりや支え合いを示す軸です。",
            "想像力や創造性、魔法のような発想力を示す軸です。",
            "予測不能さやストレス、試練の揺らぎを示す軸です。",
            "夢の中での気づきや俯瞰力、落ち着きを示す軸です。"
        ]
    }
    
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
                            longTermSection
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .scrollDisabled(selectedTab == .daily || selectedTab == .longTerm)
        }
        .navigationTitle("AI分析")
        .sheet(item: $tellerProfileToShow) { teller in
            profileSheet(teller)
        }
        .sheet(item: $attributeDetail) { detail in
            attributeDetailSheet(detail)
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
    
    private var longTermSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("長期分析 - 夢の星座")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.dreamText)
                Spacer()
                Toggle("先月と比較", isOn: $showComparison)
                    .toggleStyle(SwitchToggleStyle(tint: .dreamAccent))
                    .font(.dreamCaption)
                    .foregroundColor(.dreamTextSecondary)
            }
            
            Text("過去の夢を6属性でマッピングし、星座のように可視化します。頂点をタップすると根拠となる夢を確認できます。")
                .font(.dreamCaption)
                .foregroundColor(.dreamTextSecondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    DreamConstellationChart(
                        current: analysisData.current.asArray,
                        previous: showComparison ? analysisData.previous.asArray : [],
                        labels: attributeLabels,
                        highlightColor: selectedTeller.config.color
                    ) { index in
                        openAttributeDetail(index: index)
                    }
                    .animation(.easeInOut, value: selectedTeller)
                    .frame(height: 300)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        let strongestIndex = analysisData.current.asArray.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
                        let strongestLabel = attributeLabels[safe: strongestIndex] ?? ""
                        
                        Text("占い師 \(selectedTeller.name) からのアドバイス")
                            .font(.dreamBody)
                            .foregroundColor(.dreamTextSecondary)
                        Text("今月は \(strongestLabel) の輝きが強いですね！")
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                            .foregroundColor(selectedTeller.config.color)
                        Text(analysisData.advice)
                            .font(.system(.callout, design: .rounded))
                            .foregroundColor(.dreamText)
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    
                    Color.clear
                        .frame(height: 100)
                }
            }
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
    
    private func openAttributeDetail(index: Int) {
        guard attributeLabels.indices.contains(index) else { return }
        let label = attributeLabels[index]
        let sampleDream = dreamService.dreams.randomElement()
        let dateText: String
        let contentText: String
        let meaning = attributeMeanings[safe: index] ?? ""
        if let dream = sampleDream {
            dateText = Self.evidenceDateFormatter.string(from: dream.recordDate)
            contentText = String(dream.content.prefix(80))
        } else {
            dateText = "記録なし"
            contentText = "まだ十分な夢の記録がありません。新しい夢を記録すると分析精度が上がります。"
        }
        
        let message = """
        \(meaning)

        あなたの「\(label)」スコアを高めた夢はこちらです。
        日付: \(dateText)
        内容: \(contentText)
        """
        
        attributeDetail = AttributeDetail(attribute: label, message: message)
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
    
    private func attributeDetailSheet(_ detail: AttributeDetail) -> some View {
        NavigationStack {
            ZStack {
                Color.clear.dreamBackground()
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(detail.attribute)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundColor(.dreamText)
                    Text(detail.message)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.dreamText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("属性の根拠")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { attributeDetail = nil }
                        .foregroundColor(.dreamAccent)
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
    
    private static let evidenceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "y/MM/dd"
        return formatter
    }()
}

// MARK: - Dream Constellation Chart

private struct DreamConstellationChart: View {
    let current: [Double]
    let previous: [Double]
    let labels: [String]
    let highlightColor: Color
    let onSelect: (Int) -> Void
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2 * 0.85
            let count = min(current.count, labels.count)
            
            ZStack {
                grid(center: center, radius: radius, count: count)
                
                if !previous.isEmpty {
                    polygonPath(values: previous, center: center, radius: radius, count: count)
                        .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round, dash: [6, 6]))
                }
                
                polygonPath(values: current, center: center, radius: radius, count: count)
                    .stroke(highlightColor.opacity(0.9), style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
                    .shadow(color: highlightColor.opacity(0.5), radius: 6, x: 0, y: 0)
                
                starNodes(values: current, center: center, radius: radius, count: count)
                
                labelLayer(center: center, radius: radius, count: count)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
    
    private func angle(for index: Int, total: Int) -> Double {
        let step = 2 * Double.pi / Double(total)
        return Double(index) * step - Double.pi / 2
    }
    
    private func point(for value: Double, index: Int, center: CGPoint, radius: CGFloat, total: Int) -> CGPoint {
        let clamped = max(0, min(1, value))
        let angle = angle(for: index, total: total)
        let r = radius * clamped
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * r,
            y: center.y + CGFloat(sin(angle)) * r
        )
    }
    
    private func grid(center: CGPoint, radius: CGFloat, count: Int) -> some View {
        let rings: [CGFloat] = [0.25, 0.5, 0.75, 1.0]
        
        return ZStack {
            ForEach(rings, id: \.self) { ring in
                polygonPath(values: Array(repeating: Double(ring), count: count), center: center, radius: radius, count: count)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            
            ForEach(0..<count, id: \.self) { idx in
                Path { path in
                    path.move(to: center)
                    let end = point(for: 1.0, index: idx, center: center, radius: radius, total: count)
                    path.addLine(to: end)
                }
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
        }
    }
    
    private func polygonPath(values: [Double], center: CGPoint, radius: CGFloat, count: Int) -> Path {
        var path = Path()
        guard count > 0 else { return path }
        
        for idx in 0..<count {
            let point = point(for: values[safe: idx] ?? 0, index: idx, center: center, radius: radius, total: count)
            if idx == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
    
    private func starNodes(values: [Double], center: CGPoint, radius: CGFloat, count: Int) -> some View {
        ForEach(0..<count, id: \.self) { idx in
            let point = point(for: values[safe: idx] ?? 0, index: idx, center: center, radius: radius, total: count)
            Circle()
                .fill(Color.white)
                .frame(width: 9, height: 9)
                .overlay(
                    Circle()
                        .stroke(highlightColor.opacity(0.9), lineWidth: 1.6)
                )
                .shadow(color: highlightColor.opacity(0.9), radius: 6, x: 0, y: 0)
                .position(point)
        }
    }
    
    private func labelLayer(center: CGPoint, radius: CGFloat, count: Int) -> some View {
        ForEach(Array(labels.prefix(count).enumerated()), id: \.offset) { item in
            let idx = item.offset
            let basePoint = point(for: 1.05, index: idx, center: center, radius: radius, total: count)
            Button {
                onSelect(idx)
            } label: {
                Text(item.element)
                    .font(.dreamCaption)
                    .foregroundColor(.dreamText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .position(basePoint)
        }
    }
}

// MARK: - Safe index helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
