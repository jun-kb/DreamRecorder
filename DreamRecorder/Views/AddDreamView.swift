import SwiftUI
import FirebaseAI

// 夢の追加画面
struct AddDreamView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    let recordDate: Date
    var dreamToEdit: Dream? = nil
    
    @State private var dreamContent = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // このView専用のSpeechManagerを初期化
    @StateObject private var speechManager = SpeechRecognizerManager()
    
    @State private var isRefining = false
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    
    @State private var showResetAlert = false
    
    private var isEditing: Bool {
        dreamToEdit != nil
    }
        
    private var dateToShow: Date {
        dreamToEdit?.recordDate ?? recordDate
    }
        
    private var title: String {
        isEditing ? "夢を編集" : "夢を記録"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color.clear.dreamBackground()
                
                Form {
                    Section(header: Text(isEditing ? "夢の日付" : "記録する日付").foregroundColor(.dreamTextSecondary)) {
                        HStack {
                            Spacer()
                            Text(dateToShow, style: .date)
                                .fontWeight(.bold)
                                .foregroundColor(.dreamText)
                            Spacer()
                        }
                        .listRowBackground(Color.dreamCard)
                    }
                    
                    Section {
                        TextEditor(text: $dreamContent)
                            .frame(minHeight: 200)
                            .scrollContentBackground(.hidden) // TextEditorの背景を透明に
                            .background(Color.clear)
                            .foregroundColor(.dreamText)
                            .placeholder(when: dreamContent.isEmpty) {
                                Text("今日見た夢を記録しましょう...")
                                    .foregroundColor(.dreamTextSecondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                            .listRowBackground(Color.dreamCard)
                    } header: {
                        HStack {
                            Text("夢の内容")
                                .foregroundColor(.dreamTextSecondary)
                            Spacer()
                                                
                            Button {
                                Task {
                                    await refineDreamContent()
                                }
                            } label: {
                                if isRefining {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.dreamAccent)
                                } else {
                                    Label("AIで清書", systemImage: "pencil.and.scribble")
                                }
                            }
                            .font(.dreamCaption)
                            .buttonStyle(.borderless)
                            .tint(.dreamAccent)
                            .disabled(isRefining || isSaving || dreamContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } footer: {
                        VStack(alignment: .center) {
                                            
                            if speechManager.isRecording {
                                Text(speechManager.transcript.isEmpty ? "認識中..." : speechManager.transcript)
                                    .font(.dreamCaption)
                                    .foregroundColor(.dreamTextSecondary)
                                    .padding(.top, 5)
                                    .frame(minHeight: 30)
                            }
                                            
                            Button {
                                // 録音/停止 トグル
                                Task {
                                    if speechManager.isRecording {
                                        speechManager.stopRecording()
                                    } else {
                                        await speechManager.startRecording()
                                    }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(speechManager.isRecording ? Color.red : Color.dreamAccent)
                                        .frame(width: 60, height: 60)
                                        .shadow(color: (speechManager.isRecording ? Color.red : Color.dreamAccent).opacity(0.5), radius: 10, x: 0, y: 5)
                                    
                                    Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .disabled(isSaving || isRefining)
                            .padding(.top, 16)
    
                            // エラーメッセージ表示
                            if let speechError = speechManager.errorMessage {
                                Text(speechError)
                                    .font(.dreamCaption)
                                    .foregroundColor(.red)
                                    .padding(.top, 5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Section {
                        Button(action: confirmSaveOrUpdate) {
                            if isSaving {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .tint(.white)
                                    Text("保存中...")
                                        .padding(.leading, 8)
                                    Spacer()
                                }
                            } else {
                                HStack {
                                    Spacer()
                                    Text("保存")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                            }
                        }
                        .disabled(dreamContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || isRefining)
                        .listRowBackground(Color.dreamAccent)
                        .foregroundColor(.white)
                    }
                }
                .scrollContentBackground(.hidden) // Formの背景を透明に
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(.white) // キャンセルボタンを白くして視認性向上
                    .disabled(isSaving || isRefining)
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                Task {
                    await speechManager.requestPermission()
                }
                
                if let dream = dreamToEdit, dreamContent.isEmpty {
                    dreamContent = dream.content
                }
            }
            .onChange(of: speechManager.isRecording) {
                if !speechManager.isRecording {
                    let recognizedText = speechManager.finalTranscript
                    if !recognizedText.isEmpty {
                        // 既存のテキストの後ろにスペースを空けて追記する
                        if dreamContent.isEmpty {
                            dreamContent = recognizedText
                        } else {
                            dreamContent += " " + recognizedText
                        }
                    }
                }
            }
            .onChange(of: isSaving) {
                if isSaving && speechManager.isRecording {
                    speechManager.stopRecording()
                }
            }
            .onDisappear {
                if speechManager.isRecording {
                    speechManager.stopRecording()
                }
            }
            .alert("確認", isPresented: $showResetAlert) {
                Button("リセットして保存", role: .destructive) {
                    // 「リセットする」を選んだ場合
                    Task {
                        await performSave(resetInterpretation: true)
                    }
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("夢の内容を編集すると、AIによる分析結果はリセットされます。\nよろしいですか？")
            }
        }
        .preferredColorScheme(.dark) // ステータスバーとナビゲーションタイトルを白くする
    }
    
    // 「保存」ボタンが押された時の確認処理
    private func confirmSaveOrUpdate() {
        let content = dreamContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
            
        // 1. 編集モードである
        // 2. 既にAIの分析結果が存在する
        // 3. 夢の内容が変更されている
        // 上記3つの条件をすべて満たす場合のみ、アラートを表示
        if isEditing,
            dreamToEdit?.interpretation != nil,
            dreamToEdit?.content != content {
            
            showResetAlert = true // アラートを表示
        
        } else {
            // 追加モード、または分析結果がない、または内容が変更されていない場合
            // → そのままアラートなしで保存
            Task {
                await performSave(resetInterpretation: false)
            }
        }
    }
    
    // 実際の保存・更新処理
    private func performSave(resetInterpretation: Bool) async {
        let content = dreamContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        await MainActor.run { isSaving = true }
        
        guard let userId = authManager.userId else {
            let error = AppError.authenticationRequired
            ErrorLogger.logError(error, context: "AddDreamView.performSave")
            errorMessage = ErrorLogger.userFacingMessage(from: error)
            showError = true
            isSaving = false
            return
        }
            
        do {
            if let dreamToEdit = self.dreamToEdit {
                // 編集モード
                try await dreamService.updateDream(
                    dream: dreamToEdit,
                    newContent: content,
                    resetInterpretation: resetInterpretation, // ⇐ アラートの結果を渡す
                    userId: userId
                )
                
                // 内容が変更された場合は再分析（バックグラウンドで実行）
                if resetInterpretation, let dreamId = dreamToEdit.id {
                    Task {
                        await dreamService.analyzeDreamScores(
                            dreamId: dreamId,
                            content: content,
                            userId: userId
                        )
                    }
                }
            } else {
                // 追加モード
                let dreamId = try await dreamService.saveDream(
                    content: content,
                    recordDate: self.recordDate,
                    userId: userId
                )
                
                // 保存後にバックグラウンドで6属性分析を実行
                Task {
                    await dreamService.analyzeDreamScores(
                        dreamId: dreamId,
                        content: content,
                        userId: userId
                    )
                }
            }
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            // AppErrorに分類してログ記録
            let appError = ErrorLogger.classify(error, context: .network)
            ErrorLogger.logError(appError, context: "AddDreamView.performSave")
            // 4-6. ユーザー向けメッセージ取得 → 設定 → alert表示
            await MainActor.run {
                errorMessage = ErrorLogger.userFacingMessage(from: appError)
                showError = true
                isSaving = false
            }
        }
    }
    
    // AIを使ってテキストを清書する
    private func refineDreamContent() async {
        let originalContent = dreamContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !originalContent.isEmpty else { return }
            
        await MainActor.run {
            isRefining = true
            errorMessage = "" // エラーをリセット
        }
            
        let prompt = """
        あなたは優秀な編集者です。
        以下のテキストに含まれる誤字脱字、文法的な誤りを修正し、句読点を適切に補い、自然な日本語の文章に清書してください。
        元のテキストの内容を勝手に変更したり、情報を追加したりしないでください。
        清書したテキストだけを返してください。

        元のテキスト:
        \(originalContent)
        """
            
        do {
            let model = ai.generativeModel(modelName: "gemini-2.5-flash")
            let response = try await model.generateContent(prompt)
                
            if let refinedText = response.text {
                // メインスレッドでUI（dreamContent）を更新
                await MainActor.run {
                    self.dreamContent = refinedText
                }
            } else {
                throw AppError.aiServiceError("AIからの応答が空でした。")
            }
                
        } catch {
            let appError = ErrorLogger.classify(error, context: .ai)
            ErrorLogger.logError(appError, context: "AddDreamView.refineDreamContent")
            await MainActor.run {
                errorMessage = ErrorLogger.userFacingMessage(from: appError)
                showError = true
            }
        }
            
        // 処理が完了したら必ずローディングを解除
        await MainActor.run {
            isRefining = false
        }
    }
}
