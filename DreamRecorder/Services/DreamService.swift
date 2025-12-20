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
    
    // 夢を保存（保存したドキュメントIDを返す）
    @discardableResult
    func saveDream(content: String, recordDate: Date, userId: String) async throws -> String {
        guard !userId.isEmpty else {
            throw AppError.authenticationRequired
        }
        
        let dream = Dream(
            content: content,
            recordDate: recordDate,
            createdAt: Date()
        )
        
        let docRef = try db.collection("users")
            .document(userId)
            .collection("dreams")
            .addDocument(from: dream)
        
        return docRef.documentID
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
            // エラーハンドリング（呼び出し元でUIエラー表示を行うため、ここではログ記録のみ）
            let appError = ErrorLogger.classify(error, context: .ai)
            ErrorLogger.logError(appError, context: "DreamService.interpretDream")
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
    
    // MARK: - 長期分析用スコア算出
    
    /// 夢分析スコア用のJSON Schema
    private var analysisScoresSchema: Schema {
        Schema.object(
            properties: [
                "serenity": .double(),
                "vitality": .double(),
                "connection": .double(),
                "creativity": .double(),
                "security": .double(),
                "awareness": .double()
            ]
        )
    }
    
    /// AI（Gemini）を使って夢の6属性スコアを分析し、Firestoreに保存する
    /// - Note: 分析失敗時も夢の保存自体には影響しない（非クリティカルエラー）
    func analyzeDreamScores(dreamId: String, content: String, userId: String) async {
        do {
            guard !userId.isEmpty else {
                throw AppError.invalidUserId
            }
            
            // AIプロンプト
            let promptText = """
            夢の内容を分析し、以下の6属性について0.0〜1.0のスコアで評価してください。
            各属性は「高い値=ポジティブ」として評価してください。
            
            - serenity: 心の穏やかさ、感情の安定度（高い=安らぎがある）
            - vitality: エネルギー、行動力、冒険心（高い=活動的で前向き）
            - connection: 人とのつながり、社会的相互作用（高い=人間関係が豊か）
            - creativity: 想像力、象徴性、非現実的要素（高い=幻想的で創造的）
            - security: 安心感、保護感（高い=脅威がなく安心できる）
            - awareness: 夢の中での気づき、自己認識（高い=意識的で洞察がある）
            
            夢の内容:
            \(content)
            """
            
            // モデルの初期化（JSON Schema を使用）
            let model = ai.generativeModel(
                modelName: "gemini-2.5-flash",
                generationConfig: GenerationConfig(
                    responseMIMEType: "application/json",
                    responseSchema: analysisScoresSchema
                ),
                systemInstruction: ModelContent(role: "system", parts: "あなたは夢分析の専門家です。夢の内容を客観的に分析し、各属性のスコアを返してください。")
            )
            
            let userContent = ModelContent(role: "user", parts: promptText)
            let response = try await model.generateContent([userContent])
            
            guard let responseText = response.text else {
                throw AppError.aiServiceError("AIからの応答が空でした。")
            }
            
            // JSONをデコード（responseSchemaにより確実にJSON形式で返ってくる）
            guard let jsonData = responseText.data(using: .utf8) else {
                throw AppError.aiServiceError("JSONデータの変換に失敗しました。")
            }
            
            let decoded = try JSONDecoder().decode(AnalysisScoresResponse.self, from: jsonData)
            
            // スコアをクランプしてDreamAnalysisScoresを作成
            let scores = DreamAnalysisScores(
                serenity: clampScore(decoded.serenity),
                vitality: clampScore(decoded.vitality),
                connection: clampScore(decoded.connection),
                creativity: clampScore(decoded.creativity),
                security: clampScore(decoded.security),
                awareness: clampScore(decoded.awareness),
                analyzedAt: Date()
            )
            
            // Firestoreに保存
            let scoresData: [String: Any] = [
                "analysisScores": [
                    "serenity": scores.serenity,
                    "vitality": scores.vitality,
                    "connection": scores.connection,
                    "creativity": scores.creativity,
                    "security": scores.security,
                    "awareness": scores.awareness,
                    "analyzedAt": Timestamp(date: scores.analyzedAt)
                ]
            ]
            
            try await db.collection("users")
                .document(userId)
                .collection("dreams")
                .document(dreamId)
                .updateData(scoresData)
            
        } catch {
            // 非クリティカルエラー：ログ記録のみ、ユーザーには通知しない
            let appError = ErrorLogger.classify(error, context: .ai)
            ErrorLogger.logError(appError, context: "DreamService.analyzeDreamScores")
        }
    }
    
    /// スコアを0.0〜1.0の範囲にクランプ
    private func clampScore(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }
}

// MARK: - AI Response Model

private struct AnalysisScoresResponse: Decodable {
    let serenity: Double
    let vitality: Double
    let connection: Double
    let creativity: Double
    let security: Double
    let awareness: Double
}
