import Foundation
import FirebaseFirestore

// 1日の振り返り日記モデル
struct Reflection: Identifiable, Codable {
    @DocumentID var id: String?
    let content: String
    let recordDate: Date
    let createdAt: Date
}
