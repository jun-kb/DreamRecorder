import SwiftUI
import Combine
import Speech
import AVFoundation
import AVFAudio

// 音声認識を一元管理するクラス
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
                let errorMessage = "マイクまたは音声認識の許可がありません。設定アプリから許可してください。"
                self.errorMessage = errorMessage
                ErrorLogger.logError(AppError.aiServiceError(errorMessage), context: "SpeechRecognizerManager.requestPermission")
            }
        }
    }

    /// 2. 録音と認識の開始
    func startRecording() async {
        guard isAuthorized else {
            let errorMessage = "許可がありません。"
            self.errorMessage = errorMessage
            ErrorLogger.logError(AppError.aiServiceError(errorMessage), context: "SpeechRecognizerManager.startRecording")
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
            let appError = AppError.audioSessionError(error)
            ErrorLogger.logError(appError, context: "SpeechRecognizerManager.startRecording")
            self.errorMessage = ErrorLogger.userFacingMessage(from: appError)
            return
        }

        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = self.recognitionRequest else {
            let errorMessage = "SFSpeechAudioBufferRecognitionRequestの作成に失敗"
            let appError = AppError.aiServiceError(errorMessage)
            ErrorLogger.logError(appError, context: "SpeechRecognizerManager.startRecording")
            self.errorMessage = ErrorLogger.userFacingMessage(from: appError)
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
                                
                    if let error = error {
                        let appError = AppError.audioSessionError(error)
                        ErrorLogger.logError(appError, context: "SpeechRecognizerManager.recognitionTask")
                        self.errorMessage = ErrorLogger.userFacingMessage(from: appError)
                    }
                                
                    if error != nil || isFinal {
                        self.stopRecordingInternal()
                    }
                }
            }
        } catch {
            let appError = AppError.audioSessionError(error)
            ErrorLogger.logError(appError, context: "SpeechRecognizerManager.startRecording - audioEngine.start")
            self.errorMessage = ErrorLogger.userFacingMessage(from: appError)
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
