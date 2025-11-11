// MARK: - 1. まずFirebaseのセットアップ

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseAI
import Speech
import AVFoundation
import AVFAudio

// MARK: - App Entry Point
@main
struct DreamRecorderApp: App {
    // Firebaseの初期化をAppDelegateに委任
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            // アプリの最初のビューをContentViewに
            ContentView()
        }
    }
}

// MARK: - Dream Model
struct Dream: Identifiable, Codable {
    @DocumentID var id: String?
    let content: String
    let recordDate: Date
    let createdAt: Date
    var interpretation: String?
}

// MARK: - Dream Service (Firebaseとのやり取り)
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
                self?.errorMessage = error.localizedDescription
                return
            }
            
            guard let snapshot else { return }
            
            // 変更があったドキュメントをデコード
            self?.dreams = snapshot.documents.compactMap { doc in
                try? doc.data(as: Dream.self)
            }
        }
    }
    
    // 夢を保存
    func saveDream(content: String, recordDate: Date, userId: String) async throws {
        guard !userId.isEmpty else {
            throw NSError(domain: "", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "ユーザーがログインしていません"])
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
        guard let dreamId = dream.id else { return }
        guard !userId.isEmpty else { return }
        
        try await db.collection("users")
            .document(userId)
            .collection("dreams")
            .document(dreamId)
            .delete()
    }
    // MARK: - 夢占い機能
        
    /// AI（Gemini）を使って夢を解釈し、結果をFirestoreに保存する
    func interpretDream(dream: Dream, userId: String) async {
        guard let dreamId = dream.id else {
            errorMessage = "夢のIDがありません。"
            return
        }
        guard !userId.isEmpty else {
            errorMessage = "ユーザーIDがありません。"
            return
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
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "AIからの応答が空でした。"])
            }
                
            // Firestoreに結果（interpretation）を保存
            try await db.collection("users")
                .document(userId)
                .collection("dreams")
                .document(dreamId)
                .updateData(["interpretation": interpretation])
                
        } catch {
            // エラーハンドリング
            await MainActor.run {
                self.errorMessage = "夢占いに失敗しました: \(error.localizedDescription)"
            }
        }
            
        // UIを「解釈中」から元に戻す
        await MainActor.run {
            self.interpretingDreamId = nil
        }
    }
    // 夢を更新 (編集)
    func updateDream(dream: Dream, newContent: String, resetInterpretation: Bool, userId: String) async throws {
        guard let dreamId = dream.id else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "夢のIDがありません"])
        }
        guard !userId.isEmpty else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーIDがありません"])
        }
        
        // 更新するデータを準備
        var dataToUpdate: [String: Any] = [
            "content": newContent
        ]
        
        if resetInterpretation {
            // interpretation フィールドを削除（nil に設定）します
            // ※ .delete() を使うには import FirebaseFirestore が必要（ファイル先頭にあるはずです）
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

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var dreamService = DreamService()
    @StateObject private var authManager = AuthManager() // 認証状態を管理するクラスを新設
    
    var body: some View {
        Group {
            if authManager.isSignedIn { // 管理クラスの状態を監視
                DreamListView()
                    .environmentObject(dreamService)
                    // 認証状態が変わったらDreamServiceにも伝える
                    .environmentObject(authManager)
            } else {
                SignInView(authManager: authManager) // 管理クラスを渡す
            }
        }
    }
}

// 認証状態を一元管理するクラス（例）
@MainActor
class AuthManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var userId: String?

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        // 認証状態の変更をリッスン
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.isSignedIn = (user != nil)
            self?.userId = user?.uid
        }
    }
    
    func signInAnonymously() async throws {
        guard !isSignedIn else { return }
        try await Auth.auth().signInAnonymously()
    }
    
    deinit {
        // リスナーを解除
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }
}

// MARK: - Sign In View (簡易版・匿名ログイン)
struct SignInView: View {
    @ObservedObject var authManager: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 80))
                .foregroundColor(.purple)
            
            Text("夢記録アプリ")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("あなたの夢を記録・分析します")
                .foregroundColor(.secondary)
            
            if isLoading {
                ProgressView()
            } else {
                Button("はじめる") {
                    Task {
                        await signIn()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top)
            }
        }
        .padding()
    }
    
    private func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.signInAnonymously()
        } catch {
            print("💥💥💥 サインイン失敗 (詳細): \(error) 💥💥💥")
            isLoading = false
            errorMessage = "ログインに失敗しました。ネットワーク接続を確認してください。"
        }
    }
}

// MARK: - Dream List View
// MARK: - Dream List View
struct DreamListView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showingDreamSheet = false // 「追加」「編集」兼用
    @State private var dreamToEdit: Dream? = nil  // 編集対象の夢を保持
    
    // 1. 選択された日付を管理するState
    @State private var selectedDate: Date = Date()
    
    // 2. 選択された日付に基づいて夢をフィルタリングする
    private var filteredDreams: [Dream] {
        dreamService.dreams.filter { dream in
            // 夢の日付(recordDate)と選択された日付(selectedDate)が同じ日かどうかを判定
            Calendar.current.isDate(dream.recordDate, inSameDayAs: selectedDate)
        }
    }
    
    var body: some View {
        NavigationView {
            // 3. カレンダーとリストを縦に並べる
            VStack {
                // 4. カレンダーUIの追加
                DatePicker(
                    "日付選択",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical) // これでカレンダー表示になる
                .padding(.horizontal)
                
                // 5. フィルタリングされたリストの表示
                ZStack {
                    // フィルタリングした結果、夢がない場合に表示
                    if filteredDreams.isEmpty && !dreamService.isLoading {
                        VStack(spacing: 16) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("この日の夢はありません")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("右上の + ボタンから記録を始めましょう")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 60) // カレンダーの下に表示されるよう調整
                    } else {
                        // フィルタリングされた夢のリスト
                        List {
                            ForEach(filteredDreams) { dream in
                                Button{
                                    self.dreamToEdit = dream
                                    self.showingDreamSheet = true
                                } label: {
                                    DreamRow(dream: dream)
                                        // DreamRowにEnvironmentObjectを渡す
                                        .environmentObject(dreamService)
                                        .environmentObject(authManager)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete(perform: deleteDreams)
                        }
                    }
                    
                    if dreamService.isLoading {
                        ProgressView()
                    }
                }
                // Listがカレンダーを押し出さないようにサイズを固定
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("夢の記録")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        self.dreamToEdit = nil
                        self.showingDreamSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingDreamSheet) {
                AddDreamView(recordDate: selectedDate, dreamToEdit: dreamToEdit)
                    .environmentObject(dreamService)
                    .environmentObject(authManager)
            }
            .onChange(of: authManager.userId) {
                dreamService.setupListener(userId: authManager.userId ?? "")
            }
            .task {
                dreamService.setupListener(userId: authManager.userId ?? "")
            }
        }
    }
    
    private func deleteDreams(at offsets: IndexSet) {
        guard let userId = authManager.userId else { return }
        
        // フィルタリングされたリスト(filteredDreams)から削除対象の夢を取得
        let dreamsToDelete = offsets.map { filteredDreams[$0] }
        
        for dream in dreamsToDelete {
            Task {
                try? await dreamService.deleteDream(dream, userId: userId)
            }
        }
    }
}

// MARK: - Dream Row (一覧の各行)
struct DreamRow: View {
    let dream: Dream
    // サービスと認証情報にアクセスするためにEnvironmentObjectを追加
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dream.recordDate, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
                
            Text(dream.content)
                .font(.body)
                .lineLimit(3)
            
            // --- 夢占いUIの追加 ---
            if let interpretation = dream.interpretation {
                // 1. 解釈結果がある場合
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(.top, 2)
                    Text(interpretation)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
                .padding(.top, 4)
                
            } else if dreamService.interpretingDreamId == dream.id {
                // 2. 解釈中の場合
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8) // 小さく表示
                    Text("夢を分析中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
                
            } else {
                // 3. 「占う」ボタン
                Button {
                    Task {
                        // ボタンが押されたら占いを実行
                        guard let userId = authManager.userId else { return }
                        await dreamService.interpretDream(dream: dream, userId: userId)
                    }
                } label: {
                    Label("AIで夢を占う", systemImage: "sparkles")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .buttonStyle(.bordered)
                .controlSize(.small) // 小さなボタン
                .tint(.purple)
                .padding(.top, 4)
            }
            // --- ここまで ---
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Speech Recognizer Manager
@MainActor
class SpeechRecognizerManager: ObservableObject {
    @Published var transcript: String = ""       // 認識中の（途中結果）テキスト
    @Published var finalTranscript: String = ""  // 認識が完了した最終テキスト
    @Published var isRecording: Bool = false
    @Published var errorMessage: String?
    @Published var isAuthorized: Bool = false    // 許可状態

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        // デバイスのデフォルト言語（日本語環境なら "ja-JP"）で初期化
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    }
    
    /// 1. 音声認識とマイク使用の許可を非同期で要求する
    func requestPermission() async {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                // 認証ステータス (SFSpeechRecognizerAuthorizationStatus) を返す
                continuation.resume(returning: status)
            }
        }
        let audioStatus = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        DispatchQueue.main.async {
            self.isAuthorized = (speechStatus == .authorized) && audioStatus
            if !self.isAuthorized {
                self.errorMessage = "マイクまたは音声認識の許可がありません。設定アプリから許可してください。"
            }
        }
    }

    /// 2. 録音と認識の開始
    func startRecording() async {
        guard isAuthorized else {
            errorMessage = "許可がありません。"
            // 許可がない場合は再度要求を試みる
            await requestPermission()
            return
        }
        guard !isRecording else { return } // 既に録音中はリターン

        // 既存のタスクをリセット
        resetRecording()
        
        await MainActor.run {
            self.errorMessage = nil
        }
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()
        
        // オーディオセッションの設定
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "オーディオセッションの設定に失敗: \(error.localizedDescription)"
            return
        }

        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = self.recognitionRequest else {
            errorMessage = "SFSpeechAudioBufferRecognitionRequestの作成に失敗"
            return
        }
        recognitionRequest.shouldReportPartialResults = true // 途中結果も取得
        
        // audioEngine.prepare()

        // オーディオエンジン（マイク）の準備
        let inputNode = audioEngine.inputNode
        let mainMixer = audioEngine.mainMixerNode
        audioEngine.disconnectNodeOutput(mainMixer)
        
        // マイクからの入力をバッファにアペンドする
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()

        do {
            try audioEngine.start()
            isRecording = true
            transcript = ""
            finalTranscript = ""

            // 認識タスクの開始
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self = self else { return }
                                
                    var isFinal = false
                                
                    if let result = result {
                        self.transcript = result.bestTranscription.formattedString
                        isFinal = result.isFinal
                    }
                                
                    if error != nil || isFinal {
                        self.stopRecordingInternal()
                    }
                }
            }
        } catch {
            errorMessage = "オーディオエンジンの開始に失敗: \(error.localizedDescription)"
            stopRecordingInternal()
        }
    }

    /// 3. 録音と認識の停止（ユーザーがボタンを押した時）
    func stopRecording() {
        stopRecordingInternal()
    }
    
    /// 内部用の停止処理（エラー時や完了時にも呼ばれる）
    private nonisolated func stopRecordingInternal() {
        Task { @MainActor [weak self] in
            
            guard let self = self else { return }
                
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            // タップを削除する
            if self.isRecording {
                self.audioEngine.inputNode.removeTap(onBus: 0)
            }
                
            // エンジンが止まった後で、安全にリクエストを終了する
            recognitionRequest?.endAudio()
                
            // タスクを完了させる
            recognitionTask?.finish()
                
            // 最後にプロパティを nil にする
            //    (万が一タップがまだ動いていても、Fix 1により安全にスキップされる)
            self.finalTranscript = self.transcript
                
            self.recognitionTask = nil
            self.recognitionRequest = nil
            self.isRecording = false
        }
    }
    
    /// 録音状態をリセットする
    private nonisolated func resetRecording() {
        stopRecordingInternal()
        Task { @MainActor in
            self.transcript = ""
            self.finalTranscript = ""
            // self.errorMessage = nil
        }
    }
    
    deinit {
        stopRecordingInternal()
    }
}

// MARK: - Add Dream View (夢を追加)
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
            Form {
                Section(header: Text(isEditing ? "夢の日付" : "記録する日付")) {
                    HStack {
                        Spacer()
                        Text(dateToShow, style: .date)
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
                
                Section {
                    TextEditor(text: $dreamContent)
                        .frame(minHeight: 200)
                        .placeholder(when: dreamContent.isEmpty) {
                            Text("今日見た夢を記録しましょう...")
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                } header: {
                    HStack {
                        Text("夢の内容")
                        Spacer()
                                            
                        Button {
                            Task {
                                await refineDreamContent()
                            }
                        } label: {
                            if isRefining {
                                ProgressView()
                                    .scaleEffect(0.7) // 小さく表示
                            } else {
                                Label("AIで清書", systemImage: "pencil.and.scribble")
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .tint(.blue)
                        .disabled(isRefining || isSaving || dreamContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } footer: {
                    VStack(alignment: .center) {
                                        
                        if speechManager.isRecording {
                            Text(speechManager.transcript.isEmpty ? "認識中..." : speechManager.transcript)
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                            Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 44)) // サイズを大きく
                                .foregroundColor(speechManager.isRecording ? .red : (speechManager.isAuthorized ? .blue : .gray))
                        }
                        // 録音中、保存中、許可がない場合はボタンの挙動を制御
                        .disabled(isSaving || isRefining)
                        .padding(.top, 8)

                        // エラーメッセージ表示
                        if let speechError = speechManager.errorMessage {
                            Text(speechError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 5)
                        }
                    }
                    .frame(maxWidth: .infinity) // 中央揃えのため
                }
                
                Section {
                    Button(action: confirmSaveOrUpdate) {
                        if isSaving {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
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
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
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
    }
    
    /// 「保存」ボタンが押された時の確認処理
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
    
    /// 実際の保存・更新処理
    private func performSave(resetInterpretation: Bool) async {
        let content = dreamContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        await MainActor.run { isSaving = true }
        
        guard let userId = authManager.userId else {
            errorMessage = "ユーザーが認証されていません。"
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
            } else {
                // 追加モード
                try await dreamService.saveDream(
                    content: content,
                    recordDate: self.recordDate,
                    userId: userId
                )
            }
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isSaving = false
            }
        }
    }
    
    /// AIを使ってテキストを清書する
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
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "AIからの応答が空でした。"])
            }
                
        } catch {
            await MainActor.run {
                errorMessage = "文章の清書に失敗しました: \(error.localizedDescription)"
                showError = true
            }
        }
            
        // 処理が完了したら必ずローディングを解除
        await MainActor.run {
            isRefining = false
        }
    }
}

// MARK: - Helper Extension (TextEditorのプレースホルダー用)
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if shouldShow {
                placeholder()
            }
            self
        }
    }
}
