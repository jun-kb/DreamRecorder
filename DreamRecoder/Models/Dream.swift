import Foundation
import FirebaseFirestore

// Dream Model
struct Dream: Identifiable, Codable {
    @DocumentID var id: String?
    let content: String
    let recordDate: Date
    let createdAt: Date
    var interpretation: String?
}

