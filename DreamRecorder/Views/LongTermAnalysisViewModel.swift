import SwiftUI
import Combine
import FirebaseAI

// MARK: - Average Scores

/// 月間の平均スコア
struct AverageScores: Equatable {
    let serenity: Double
    let vitality: Double
    let connection: Double
    let creativity: Double
    let security: Double
    let awareness: Double
    let dreamCount: Int
    
    var asArray: [Double] {
        [serenity, vitality, connection, creativity, security, awareness]
    }
    
    /// 最も高いスコアの属性インデックスを取得
    var strongestIndex: Int {
        asArray.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
    }
    
    /// 最も低いスコアの属性インデックスを取得
    var weakestIndex: Int {
        asArray.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
    }
    
    static var empty: AverageScores {
        AverageScores(serenity: 0, vitality: 0, connection: 0, creativity: 0, security: 0, awareness: 0, dreamCount: 0)
    }
}

// MARK: - ViewModel

@MainActor
class LongTermAnalysisViewModel: ObservableObject {
    @Published var currentMonthScores: AverageScores?
    @Published var previousMonthScores: AverageScores?
    @Published var aiAdvice: String?
    @Published var isGeneratingAdvice = false
    @Published var errorMessage: String?
    
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    
    /// 分析に必要な最低夢数
    static let minimumDreamCount = 3
    
    /// 現在の月の夢が分析可能かどうか
    var hasEnoughData: Bool {
        guard let scores = currentMonthScores else { return false }
        return scores.dreamCount >= Self.minimumDreamCount
    }
    
    /// 分析済みの夢数
    var analyzedDreamCount: Int {
        currentMonthScores?.dreamCount ?? 0
    }
    
    // MARK: - Monthly Score Calculation
    
    /// 夢リストから月間スコアを計算
    func calculateMonthlyScores(dreams: [Dream]) {
        let calendar = Calendar.current
        let now = Date()
        
        // 当月の範囲を取得
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart),
              let currentMonthEnd = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) else {
            return
        }
        
        // 当月の夢をフィルタリング（分析スコアがあるもののみ）
        let currentMonthDreams = dreams.filter { dream in
            dream.recordDate >= currentMonthStart &&
            dream.recordDate < currentMonthEnd &&
            dream.analysisScores != nil
        }
        
        // 前月の夢をフィルタリング
        let previousMonthDreams = dreams.filter { dream in
            dream.recordDate >= previousMonthStart &&
            dream.recordDate < currentMonthStart &&
            dream.analysisScores != nil
        }
        
        // スコアを集計
        currentMonthScores = calculateAverageScores(from: currentMonthDreams)
        previousMonthScores = calculateAverageScores(from: previousMonthDreams)
    }
    
    /// 夢リストから平均スコアを計算
    private func calculateAverageScores(from dreams: [Dream]) -> AverageScores? {
        let scoredDreams = dreams.compactMap { $0.analysisScores }
        guard !scoredDreams.isEmpty else { return nil }
        
        let count = Double(scoredDreams.count)
        
        let avgSerenity = scoredDreams.reduce(0) { $0 + $1.serenity } / count
        let avgVitality = scoredDreams.reduce(0) { $0 + $1.vitality } / count
        let avgConnection = scoredDreams.reduce(0) { $0 + $1.connection } / count
        let avgCreativity = scoredDreams.reduce(0) { $0 + $1.creativity } / count
        let avgSecurity = scoredDreams.reduce(0) { $0 + $1.security } / count
        let avgAwareness = scoredDreams.reduce(0) { $0 + $1.awareness } / count
        
        return AverageScores(
            serenity: avgSerenity,
            vitality: avgVitality,
            connection: avgConnection,
            creativity: avgCreativity,
            security: avgSecurity,
            awareness: avgAwareness,
            dreamCount: scoredDreams.count
        )
    }
    
    // MARK: - AI Advice Generation
    
    /// 月間傾向に基づいてAIアドバイスを生成
    func generateAdvice() async {
        guard let current = currentMonthScores else {
            errorMessage = "分析データが不足しています。"
            return
        }
        
        isGeneratingAdvice = true
        errorMessage = nil
        
        do {
            let labels = DreamAnalysisScores.attributeLabels
            let strongestLabel = labels[safe: current.strongestIndex] ?? "不明"
            let weakestLabel = labels[safe: current.weakestIndex] ?? "不明"
            
            var promptText = """
            ユーザーの夢の月間分析結果に基づいて、優しく励ますようなアドバイスを150文字程度で生成してください。
            
            今月のスコア（0.0〜1.0）:
            - 穏やかさ: \(String(format: "%.2f", current.serenity))
            - 活力: \(String(format: "%.2f", current.vitality))
            - つながり: \(String(format: "%.2f", current.connection))
            - 創造性: \(String(format: "%.2f", current.creativity))
            - 安心感: \(String(format: "%.2f", current.security))
            - 気づき: \(String(format: "%.2f", current.awareness))
            
            最も高い属性: \(strongestLabel)
            最も低い属性: \(weakestLabel)
            分析した夢の数: \(current.dreamCount)件
            """
            
            // 前月のスコアがあれば比較情報を追加
            if let previous = previousMonthScores {
                promptText += """
                
                
                先月のスコア:
                - 穏やかさ: \(String(format: "%.2f", previous.serenity))
                - 活力: \(String(format: "%.2f", previous.vitality))
                - つながり: \(String(format: "%.2f", previous.connection))
                - 創造性: \(String(format: "%.2f", previous.creativity))
                - 安心感: \(String(format: "%.2f", previous.security))
                - 気づき: \(String(format: "%.2f", previous.awareness))
                
                先月との変化も踏まえてアドバイスしてください。
                """
            }
            
            let model = ai.generativeModel(
                modelName: "gemini-2.5-flash",
                systemInstruction: ModelContent(role: "system", parts: "あなたは優しい夢分析カウンセラーです。ユーザーの夢の傾向から、ポジティブで励ましになるアドバイスを提供してください。")
            )
            
            let userContent = ModelContent(role: "user", parts: promptText)
            let response = try await model.generateContent([userContent])
            
            guard let adviceText = response.text else {
                throw AppError.aiServiceError("AIからの応答が空でした。")
            }
            
            aiAdvice = adviceText
            
        } catch {
            let appError = ErrorLogger.classify(error, context: .ai)
            ErrorLogger.logError(appError, context: "LongTermAnalysisViewModel.generateAdvice")
            errorMessage = ErrorLogger.userFacingMessage(from: appError)
        }
        
        isGeneratingAdvice = false
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
