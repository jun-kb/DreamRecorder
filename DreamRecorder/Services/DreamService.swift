import SwiftUI
import Combine
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseAI

// Firebaseとの夢のやり取りを管理するクラス
@MainActor
class DreamService: ObservableObject {
    @Published var dreams: [Dream] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var interpretingDreamId: String?
    
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    
    // 認証状態の変更（AuthManager）を監視して、リスナーを貼り替える
    func setupListener(userId: String) {
        // 既存のリスナーがあれば解除
        listenerRegistration?.remove()
        
        // userId が空なら何もしない
        guard !userId.isEmpty else {
            self.dreams = []
            return
        }
        
        self.isLoading = true
        
        let query = db.collection("users")
            .document(userId)
            .collection("dreams")
            .order(by: "recordDate", descending: true)
            
        // スナップショットリスナーを設定
        self.listenerRegistration = query.addSnapshotListener { [weak self] snapshot, error in
            self?.isLoading = false
            
            if let error {
                let appError = AppError.networkError(error)
                ErrorLogger.logError(appError, context: "DreamService.setupListener")
                self?.errorMessage = ErrorLogger.userFacingMessage(from: appError)
                return
            }
            
            guard let snapshot else { return }
            
            // 変更があったドキュメントをデコード
            var decodedDreams: [Dream] = []
            for doc in snapshot.documents {
                do {
                    let dream = try doc.data(as: Dream.self)
                    decodedDreams.append(dream)
                } catch {
                    let appError = AppError.decodingError(error)
                    ErrorLogger.logError(appError, context: "DreamService.setupListener - decoding dream \(doc.documentID)")
                    self?.errorMessage = "一部のデータの読み込みに失敗しました。"
                }
            }
            self?.dreams = decodedDreams
        }
    }
    
    // 夢を保存
    func saveDream(content: String, recordDate: Date, userId: String) async throws {
        guard !userId.isEmpty else {
            throw AppError.authenticationRequired
        }
        
        let dream = Dream(
            content: content,
            recordDate: recordDate,
            createdAt: Date()
        )
        
        try db.collection("users")
            .document(userId)
            .collection("dreams")
            .addDocument(from: dream)
    }
    
    // 夢を削除
    func deleteDream(_ dream: Dream, userId: String) async throws {
        guard let dreamId = dream.id else {
            throw AppError.missingDocumentId("夢")
        }
        guard !userId.isEmpty else {
            throw AppError.invalidUserId
        }
        
        try await db.collection("users")
            .document(userId)
            .collection("dreams")
            .document(dreamId)
            .delete()
    }

    /// AI（Gemini）を使って夢を解釈し、結果をFirestoreに保存する
    func interpretDream(dream: Dream, userId: String) async throws{
        guard let dreamId = dream.id else {
            throw AppError.missingDocumentId("夢")
        }
        guard !userId.isEmpty else {
            throw AppError.invalidUserId
        }
            
        // UIを「解釈中」の状態にする
        await MainActor.run {
            self.interpretingDreamId = dreamId
            self.errorMessage = nil
        }
            
        do {
            // AIに渡すプロンプト（指示文）
            let prompt = """
            あなたは経験豊富な夢占いの専門家です。
            以下の夢の内容を分析し、夢を見た人へポジティブで簡潔なアドバイス（100文字程度）をしてください。
            結果は占いのテキストのみを返してください。

            夢の内容:
            \(dream.content)
            """
                
            // Firebase AI (Gemini) を呼び出す
            let model = ai.generativeModel(modelName: "gemini-2.5-flash")
            let response = try await model.generateContent(prompt)
                
            guard let interpretation = response.text else {
                throw AppError.aiServiceError("AIからの応答が空でした。")
            }
                
            // Firestoreに結果（interpretation）を保存
            try await db.collection("users")
                .document(userId)
                .collection("dreams")
                .document(dreamId)
                .updateData(["interpretation": interpretation])
                
        } catch {
            // エラーハンドリング
            let appError: AppError
            if let existingAppError = error as? AppError {
                appError = existingAppError
            } else {
                appError = AppError.unknownError(error)
            }
            ErrorLogger.logError(appError, context: "DreamService.interpretDream")
            
            // UIにエラーを表示
            await MainActor.run {
                self.errorMessage = ErrorLogger.userFacingMessage(from: appError)
            }
            
            // エラーを再スローして呼び出し元に伝播
            throw appError
        }
            
        // UIを「解釈中」から元に戻す
        await MainActor.run {
            self.interpretingDreamId = nil
        }
    }
    
    // 夢を更新 (編集)
    func updateDream(dream: Dream, newContent: String, resetInterpretation: Bool, userId: String) async throws {
        guard let dreamId = dream.id else {
            throw AppError.missingDocumentId("夢")
        }
        guard !userId.isEmpty else {
            throw AppError.invalidUserId
        }
        
        // 更新するデータを準備
        var dataToUpdate: [String: Any] = [
            "content": newContent
        ]
        
        if resetInterpretation {
            // interpretation フィールドを削除（nil に設定）します
            dataToUpdate["interpretation"] = FieldValue.delete()
        }
            
        // content と (必要なら) interpretation を更新
        try await db.collection("users")
            .document(userId)
            .collection("dreams")
            .document(dreamId)
            .updateData(dataToUpdate)
    }
}
