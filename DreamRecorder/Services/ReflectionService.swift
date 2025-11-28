import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

// 振り返り日記のCRUDとリアルタイム購読を管理
@MainActor
class ReflectionService: ObservableObject {
    @Published var reflections: [Reflection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    /// 認証状態が変わったときにリスナーを張り直す
    func setupListener(userId: String) {
        listenerRegistration?.remove()
        
        guard !userId.isEmpty else {
            self.reflections = []
            return
        }
        
        isLoading = true
        let query = db.collection("users")
            .document(userId)
            .collection("reflections")
            .order(by: "recordDate", descending: true)
        
        listenerRegistration = query.addSnapshotListener { [weak self] snapshot, error in
            self?.isLoading = false
            
            if let error {
                self?.errorMessage = error.localizedDescription
                return
            }
            
            guard let snapshot else { return }
            
            self?.reflections = snapshot.documents.compactMap { doc in
                try? doc.data(as: Reflection.self)
            }
        }
    }
    
    func saveReflection(content: String, recordDate: Date, userId: String) async throws {
        guard !userId.isEmpty else {
            throw NSError(domain: "", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "ユーザーがログインしていません"])
        }
        
        let reflection = Reflection(
            content: content,
            recordDate: recordDate,
            createdAt: Date()
        )
        
        try db.collection("users")
            .document(userId)
            .collection("reflections")
            .addDocument(from: reflection)
    }
    
    func updateReflection(reflection: Reflection, newContent: String, userId: String) async throws {
        guard let reflectionId = reflection.id else {
            throw NSError(domain: "", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "日記のIDがありません"])
        }
        guard !userId.isEmpty else {
            throw NSError(domain: "", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "ユーザーIDがありません"])
        }
        
        try await db.collection("users")
            .document(userId)
            .collection("reflections")
            .document(reflectionId)
            .updateData(["content": newContent])
    }
    
    func deleteReflection(_ reflection: Reflection, userId: String) async throws {
        guard let reflectionId = reflection.id else {
            throw NSError(domain: "ReflectionServiceError", code: 0, userInfo: [NSLocalizedDescriptionKey: "日記のIDがありません。"])
        }
        guard !userId.isEmpty else {
            throw NSError(domain: "ReflectionServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "ユーザーIDがありません。"])
        }
        
        try await db.collection("users")
            .document(userId)
            .collection("reflections")
            .document(reflectionId)
            .delete()
    }
}
