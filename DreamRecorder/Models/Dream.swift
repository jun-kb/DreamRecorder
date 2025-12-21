import Foundation
import FirebaseFirestore

// Dream Model
struct Dream: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    let content: String
    let recordDate: Date
    let createdAt: Date
    var interpretation: String?
    
    // 6属性分析スコア (0.0〜1.0)
    var analysisScores: DreamAnalysisScores?
}

// MARK: - Dream Analysis Scores

/// 夢の6属性分析スコア（すべて高い値=ポジティブ）
struct DreamAnalysisScores: Codable, Equatable {
    let serenity: Double    // 穏やかさ
    let vitality: Double    // 活力
    let connection: Double  // つながり
    let creativity: Double  // 創造性
    let security: Double    // 安心感
    let awareness: Double   // 気づき
    let analyzedAt: Date
    
    /// スコアを配列として取得（チャート描画用）
    var asArray: [Double] {
        [serenity, vitality, connection, creativity, security, awareness]
    }
    
    /// 属性ラベル（日本語）
    static let attributeLabels = ["穏やかさ", "活力", "つながり", "創造性", "安心感", "気づき"]
    
    /// 属性の説明
    static let attributeMeanings = [
        "心の平穏、感情の安定度を示します。",
        "エネルギー、行動力、冒険心を示します。",
        "人とのつながり、社会的相互作用を示します。",
        "想像力、象徴性、非現実的要素を示します。",
        "安心感、保護感、ストレスの少なさを示します。",
        "夢の中での気づき、自己認識を示します。"
    ]
}
