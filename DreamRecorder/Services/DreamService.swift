import SwiftUI
import Combine
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseAI // ここを VertexAI から AI に変更

// Firebaseとの夢のやり取りを管理するクラス
@MainActor
class DreamService: ObservableObject {
    @Published var dreams: [Dream] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var interpretingDreamId: String?
    
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    // 修正: 最新SDKに合わせて FirebaseAI を使用
    // ※もし backend: .googleAI() でエラーが出る場合は引数なしの .firebaseAI() を試してください
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
    func interpretDream(dream: Dream, reflection: Reflection?, teller: FortuneTeller, userId: String) async throws {
        do {
            // 入力バリデーション
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
            
            // deferでクリーンアップを保証
            defer {
                self.interpretingDreamId = nil
            }
            
            // AIに渡すプロンプト
            let promptText: String
            if let reflection {
                promptText = """
                以下の昨日の日記と夢の内容を関連付けて分析し、500文字程度で占ってください。回答は「今日の夢占いは〜、昨日の日記を踏まえると〜」で始めてください。

                夢の内容:
                \(dream.content)

                昨日の日記:
                \(reflection.content)
                """
            } else {
                promptText = """
                夢の内容から200文字程度で占ってください。回答は「今日の夢占いは〜」で始めてください。

                夢の内容:
                \(dream.content)
                """
            }
                
            // モデルの初期化 (Gemini 2.5 Flash)
            let model = ai.generativeModel(
                modelName: "gemini-2.5-flash",
                systemInstruction: ModelContent(role: "system", parts: teller.systemInstruction)
            )
            
            // プロンプトを ModelContent で包んで渡す（String は PartsRepresentable に準拠）
            let userContent = ModelContent(role: "user", parts: promptText)
            let response = try await model.generateContent([userContent])
                
            guard let interpretation = response.text else {
                throw AppError.aiServiceError("AIからの応答が空でした。")
            }
                
            // Firestoreに結果を保存
            try await db.collection("users")
                .document(userId)
                .collection("dreams")
                .document(dreamId)
                .updateData(["interpretation": interpretation])
                
        } catch {
            // エラーハンドリング
            let appError = ErrorLogger.classify(error, context: .ai)
            ErrorLogger.logError(appError, context: "DreamService.interpretDream")
            
            await MainActor.run {
                self.errorMessage = ErrorLogger.userFacingMessage(from: appError)
            }
            
            throw appError
        }
    }
    
    // 夢を更新
    func updateDream(dream: Dream, newContent: String, resetInterpretation: Bool, userId: String) async throws {
        guard let dreamId = dream.id else {
            throw AppError.missingDocumentId("夢")
        }
        guard !userId.isEmpty else {
            throw AppError.invalidUserId
        }
        
        var dataToUpdate: [String: Any] = [
            "content": newContent
        ]
        
        if resetInterpretation {
            dataToUpdate["interpretation"] = FieldValue.delete()
        }
            
        try await db.collection("users")
            .document(userId)
            .collection("dreams")
            .document(dreamId)
            .updateData(dataToUpdate)
    }
}