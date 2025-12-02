import SwiftUI
import FirebaseAI

// 1日の振り返り日記を追加/編集する画面
struct AddReflectionView: View {
    @EnvironmentObject var reflectionService: ReflectionService
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    let recordDate: Date
    var reflectionToEdit: Reflection? = nil
    
    @State private var reflectionContent = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @StateObject private var speechManager = SpeechRecognizerManager()
    @State private var isRefining = false
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    
    private var isEditing: Bool {
        reflectionToEdit != nil
    }
    
    private var title: String {
        isEditing ? "日記を編集" : "日記を記録"
    }
    
    private var dateToShow: Date {
        reflectionToEdit?.recordDate ?? recordDate
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.clear.dreamBackground()
                
                Form {
                    Section(header: Text(isEditing ? "日付" : "記録する日付").foregroundColor(.dreamTextSecondary)) {
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
                        TextEditor(text: $reflectionContent)
                            .frame(minHeight: 200)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .foregroundColor(.dreamText)
                            .placeholder(when: reflectionContent.isEmpty) {
                                Text("今日はどんな1日でしたか？感情や出来事を記録しましょう。")
                                    .foregroundColor(.dreamTextSecondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                            .listRowBackground(Color.dreamCard)
                    } header: {
                        HStack {
                            Text("日記")
                                .foregroundColor(.dreamTextSecondary)
                            Spacer()
                            
                            Button {
                                Task { await refineContent() }
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
                            .disabled(isRefining || isSaving || reflectionContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                        Button(action: save) {
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
                        .disabled(reflectionContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || isRefining)
                        .listRowBackground(Color.dreamAccent)
                        .foregroundColor(.white)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .disabled(isSaving || isRefining)
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                Task { await speechManager.requestPermission() }
                if let reflectionToEdit, reflectionContent.isEmpty {
                    reflectionContent = reflectionToEdit.content
                }
            }
            .onChange(of: speechManager.isRecording) {
                if !speechManager.isRecording {
                    let recognizedText = speechManager.finalTranscript
                    if !recognizedText.isEmpty {
                        if reflectionContent.isEmpty {
                            reflectionContent = recognizedText
                        } else {
                            reflectionContent += " " + recognizedText
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
        }
        .preferredColorScheme(.dark)
    }
    
    private func save() {
        let content = reflectionContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        Task {
            await MainActor.run { isSaving = true }
            guard let userId = authManager.userId else {
                let error = AppError.authenticationRequired
                ErrorLogger.logError(error, context: "AddReflectionView.save")
                await MainActor.run {
                    errorMessage = ErrorLogger.userFacingMessage(from: error)
                    showError = true
                    isSaving = false
                }
                return
            }
            
            do {
                if let reflectionToEdit {
                    try await reflectionService.updateReflection(
                        reflection: reflectionToEdit,
                        newContent: content,
                        userId: userId
                    )
                } else {
                    try await reflectionService.saveReflection(
                        content: content,
                        recordDate: recordDate,
                        userId: userId
                    )
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                ErrorLogger.logError(error, context: "AddReflectionView.save")
                await MainActor.run {
                    errorMessage = ErrorLogger.userFacingMessage(from: error)
                    showError = true
                    isSaving = false
                }
            }
        }
    }
    
    private func refineContent() async {
        let originalContent = reflectionContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !originalContent.isEmpty else { return }
        
        await MainActor.run {
            isRefining = true
            errorMessage = ""
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
                await MainActor.run {
                    self.reflectionContent = refinedText
                }
            } else {
                throw AppError.aiServiceError("AIからの応答が空でした。")
            }
        } catch {
            let appError: AppError
            if let existingAppError = error as? AppError {
                appError = existingAppError
            } else {
                appError = AppError.unknownError(error)
            }
            ErrorLogger.logError(appError, context: "AddReflectionView.refineContent")
            await MainActor.run {
                errorMessage = ErrorLogger.userFacingMessage(from: appError)
                showError = true
            }
        }
        
        await MainActor.run {
            isRefining = false
        }
    }
}
