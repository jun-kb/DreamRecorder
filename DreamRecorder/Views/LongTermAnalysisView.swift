import SwiftUI

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

private struct AttributeDetail: Identifiable {
    let id = UUID()
    let attribute: String
    let message: String
}

struct LongTermAnalysisView: View {
    @EnvironmentObject private var dreamService: DreamService
    
    @AppStorage("showMonthlyComparison") private var showComparison = true
    @State private var analysisData: DreamAnalysisData = .mock
    @State private var attributeDetail: AttributeDetail?
    
    private let attributeLabels = ["平穏", "活動", "絆", "創造", "ストレス", "気づき"]
    private let highlightColor = Color.dreamAccent
    
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
        NavigationStack {
            ZStack(alignment: .top) {
                Color.clear.dreamBackground()

                VStack(spacing: 12) {
                    longTermSection
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        .navigationTitle("長期分析")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $attributeDetail) { detail in
                attributeDetailSheet(detail)
            }
        }
    }
    
    private var longTermSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("夢の星座")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundColor(.dreamText)
            
            Text("過去の夢を6属性でマッピングし、星座のように可視化します。頂点をタップすると根拠となる夢を確認できます。")
                .font(.dreamCaption)
                .foregroundColor(.dreamTextSecondary)
            
            DreamConstellationChart(
                current: analysisData.current.asArray,
                previous: showComparison ? analysisData.previous.asArray : [],
                labels: attributeLabels,
                highlightColor: highlightColor
            ) { index in
                openAttributeDetail(index: index)
            }
            .frame(height: 300)
            
            VStack(alignment: .leading, spacing: 8) {
                let strongestIndex = analysisData.current.asArray.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
                let strongestLabel = attributeLabels[safe: strongestIndex] ?? ""
                
                Text("分析結果")
                    .font(.dreamBody)
                    .foregroundColor(.dreamTextSecondary)
                Text("今月は \(strongestLabel) の輝きが強いですね！")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundColor(highlightColor)
                Text(analysisData.advice)
                    .font(.system(.callout, design: .rounded))
                    .foregroundColor(.dreamText)
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
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
