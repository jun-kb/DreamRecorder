import SwiftUI

struct LongTermAnalysisView: View {
    @EnvironmentObject private var dreamService: DreamService
    @EnvironmentObject private var authManager: AuthManager
    
    @StateObject private var viewModel = LongTermAnalysisViewModel()
    @AppStorage("showMonthlyComparison") private var showComparison = true
    @State private var showAttributeGuide = false
    
    // エラーハンドリング用（ERROR_HANDLING_GUIDE.md準拠）
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let highlightColor = Color.dreamAccent
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.clear.dreamBackground()

                ScrollView {
                    VStack(spacing: 12) {
                        if viewModel.hasEnoughData {
                            longTermSection
                        } else {
                            insufficientDataSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("長期分析")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAttributeGuide) {
                attributeGuideSheet
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            // Service監視（パターンA）
            .onChange(of: dreamService.errorMessage) { _, newValue in
                if let error = newValue {
                    errorMessage = error
                    showError = true
                    dreamService.errorMessage = nil
                }
            }
            // ViewModel監視
            .onChange(of: viewModel.errorMessage) { _, newValue in
                if let error = newValue {
                    errorMessage = error
                    showError = true
                    viewModel.errorMessage = nil
                }
            }
            // 夢データが更新されたらスコアを再計算
            .onChange(of: dreamService.dreams) { _, newDreams in
                viewModel.calculateMonthlyScores(dreams: newDreams)
            }
            .onAppear {
                viewModel.calculateMonthlyScores(dreams: dreamService.dreams)
            }
        }
    }
    
    // MARK: - Insufficient Data Section
    
    private var insufficientDataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("夢の星座")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.dreamText)
                Spacer()
                Button {
                    showAttributeGuide = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.dreamAccent)
                }
            }
            
            VStack(spacing: 16) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 48))
                    .foregroundColor(.dreamTextSecondary)
                
                Text("分析にはもう少し夢の記録が必要です")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(.dreamText)
                    .multilineTextAlignment(.center)
                
                let remaining = LongTermAnalysisViewModel.minimumDreamCount - viewModel.analyzedDreamCount
                Text("あと\(max(0, remaining))件の夢を記録すると、\n6属性の分析結果が表示されます。")
                    .font(.dreamCaption)
                    .foregroundColor(.dreamTextSecondary)
                    .multilineTextAlignment(.center)
                
                if viewModel.analyzedDreamCount > 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<LongTermAnalysisViewModel.minimumDreamCount, id: \.self) { index in
                            Circle()
                                .fill(index < viewModel.analyzedDreamCount ? highlightColor : Color.white.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
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
    
    // MARK: - Long Term Section
    
    private var longTermSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("夢の星座")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.dreamText)
                Spacer()
                Button {
                    showAttributeGuide = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.dreamAccent)
                }
            }
            
            Text("今月の夢を6属性でマッピングし、星座のように可視化します。")
                .font(.dreamCaption)
                .foregroundColor(.dreamTextSecondary)
            
            // 月間比較トグル
            if viewModel.previousMonthScores != nil {
                Toggle("先月と比較", isOn: $showComparison)
                    .font(.dreamCaption)
                    .foregroundColor(.dreamTextSecondary)
                    .tint(.dreamAccent)
            }
            
            DreamConstellationChart(
                current: viewModel.currentMonthScores?.asArray ?? [],
                previous: showComparison ? (viewModel.previousMonthScores?.asArray ?? []) : [],
                labels: DreamAnalysisScores.attributeLabels,
                highlightColor: highlightColor
            )
            .frame(height: 300)
            
            analysisResultSection
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
    
    // MARK: - Analysis Result Section
    
    private var analysisResultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("分析結果")
                    .font(.dreamBody)
                    .foregroundColor(.dreamTextSecondary)
                
                Spacer()
                
                if viewModel.aiAdvice == nil && !viewModel.isGeneratingAdvice {
                    Button {
                        Task {
                            await viewModel.generateAdvice()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("アドバイスを生成")
                        }
                        .font(.dreamCaption)
                    }
                    .buttonStyle(.borderless)
                    .tint(.dreamAccent)
                }
            }
            
            if let scores = viewModel.currentMonthScores {
                let strongestLabel = DreamAnalysisScores.attributeLabels[safe: scores.strongestIndex] ?? ""
                Text("今月は「\(strongestLabel)」の輝きが強いですね！")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundColor(highlightColor)
                
                Text("\(scores.dreamCount)件の夢を分析しました")
                    .font(.dreamCaption)
                    .foregroundColor(.dreamTextSecondary)
            }
            
            if viewModel.isGeneratingAdvice {
                HStack {
                    ProgressView()
                        .tint(.dreamAccent)
                    Text("アドバイスを生成中...")
                        .font(.dreamCaption)
                        .foregroundColor(.dreamTextSecondary)
                }
                .padding(.top, 4)
            } else if let advice = viewModel.aiAdvice {
                Text(advice)
                    .font(.system(.callout, design: .rounded))
                    .foregroundColor(.dreamText)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
    
    // MARK: - Attribute Guide Sheet
    
    private var attributeGuideSheet: some View {
        NavigationStack {
            ZStack {
                Color.clear.dreamBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("夢の星座では、あなたの夢を6つの属性で分析しています。それぞれの属性が示す意味をご紹介します。")
                            .font(.system(.callout, design: .rounded))
                            .foregroundColor(.dreamTextSecondary)
                            .padding(.bottom, 8)
                        
                        ForEach(Array(DreamAnalysisScores.attributeLabels.enumerated()), id: \.offset) { index, label in
                            attributeCard(
                                label: label,
                                meaning: DreamAnalysisScores.attributeMeanings[safe: index] ?? ""
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("属性ガイド")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { showAttributeGuide = false }
                        .foregroundColor(.dreamAccent)
                }
            }
        }
    }
    
    private func attributeCard(label: String, meaning: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 14))
                .foregroundColor(.dreamAccent)
                .padding(.top, 3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.dreamText)
                Text(meaning)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.dreamTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Dream Constellation Chart

private struct DreamConstellationChart: View {
    let current: [Double]
    let previous: [Double]
    let labels: [String]
    let highlightColor: Color
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2 * 0.85
            let count = min(current.count, labels.count)
            
            ZStack {
                if count > 0 {
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
            Text(item.element)
                .font(.dreamCaption)
                .foregroundColor(.dreamText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.25))
                .cornerRadius(10)
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
