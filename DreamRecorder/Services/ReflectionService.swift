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
                let appError = AppError.networkError(error)
                ErrorLogger.logError(appError, context: "ReflectionService.setupListener")
                self?.errorMessage = ErrorLogger.userFacingMessage(from: appError)
                return
            }
            
            guard let snapshot else { return }
            
            // 変更があったドキュメントをデコード
            var decodedReflections: [Reflection] = []
            for doc in snapshot.documents {
                do {
                    let reflection = try doc.data(as: Reflection.self)
                    decodedReflections.append(reflection)
                } catch {
                    let appError = AppError.decodingError(error)
                    ErrorLogger.logError(appError, context: "ReflectionService.setupListener - decoding reflection \(doc.documentID)")
                    // デコードに失敗したドキュメントはスキップし、他のドキュメントは処理を続行
                }
            }
            self?.reflections = decodedReflections
        }
    }
    
    func saveReflection(content: String, recordDate: Date, userId: String) async throws {
        guard !userId.isEmpty else {
            throw AppError.authenticationRequired
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
            throw AppError.missingDocumentId("日記")
        }
        guard !userId.isEmpty else {
            throw AppError.invalidUserId
        }
        
        try await db.collection("users")
            .document(userId)
            .collection("reflections")
            .document(reflectionId)
            .updateData(["content": newContent])
    }
    
    func deleteReflection(_ reflection: Reflection, userId: String) async throws {
        guard let reflectionId = reflection.id else {
            throw AppError.missingDocumentId("日記")
        }
        guard !userId.isEmpty else {
            throw AppError.invalidUserId
        }
        
        try await db.collection("users")
            .document(userId)
            .collection("reflections")
            .document(reflectionId)
            .delete()
    }
}
