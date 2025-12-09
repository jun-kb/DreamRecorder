# エラーハンドリング実装ガイド

このドキュメントは、DreamRecorderアプリにおけるエラーハンドリングの実装パターンをまとめたものです。新しいビューを実装する際の参考にしてください。

---

## 目次

1. [アーキテクチャ概要](#アーキテクチャ概要)
2. [基本パターン](#基本パターン)
3. [ビュー種別ごとの実装](#ビュー種別ごとの実装)
4. [ErrorLoggerの使い方](#errorloggerの使い方)
5. [AppErrorの種類](#apperrorの種類)
6. [実装チェックリスト](#実装チェックリスト)

---

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────┐
│  View層                                                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ @State var showError: Bool                          │   │
│  │ @State var errorMessage: String                     │   │
│  │                                                     │   │
│  │ .alert() ─────────────────────────┐                 │   │
│  │                                   │                 │   │
│  │ .onChange(of: service.errorMessage) ◄── Service監視 │   │
│  │                                   │                 │   │
│  │ try-catch内でErrorLogger使用 ─────┘                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  ErrorLogger (Extensions/ErrorLogger.swift)                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ classify()      → Error を AppError に変換          │   │
│  │ logError()      → OSLog にエラーを記録              │   │
│  │ userFacingMessage() → ユーザー向けメッセージ取得    │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Service層 (DreamService, ReflectionService)                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ @Published var errorMessage: String?                │   │
│  │ Firestoreリスナーからのエラーを公開                  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 基本パターン

### 必須: State変数の定義

すべてのビューで以下のState変数を定義します。

```swift
@State private var showError = false
@State private var errorMessage = ""
```

### 必須: アラート表示

ビューの `body` に `.alert()` モディファイアを追加します。

```swift
var body: some View {
    NavigationStack {
        // ... コンテンツ ...
    }
    .alert("エラー", isPresented: $showError) {
        Button("OK", role: .cancel) { }
    } message: {
        Text(errorMessage)
    }
}
```

---

## ビュー種別ごとの実装

### パターン A: 読み取り専用ビュー

**対象**: `AllDreamsView`, `HomeView`（リスト表示部分）

Serviceの `errorMessage` を監視するだけでOK。

```swift
struct MyReadOnlyView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var reflectionService: ReflectionService
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            // ... コンテンツ ...
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        // ↓ Service監視（読み取り系ビューでは必須）
        .onChange(of: dreamService.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
                showError = true
                dreamService.errorMessage = nil  // リセット
            }
        }
        .onChange(of: reflectionService.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
                showError = true
                reflectionService.errorMessage = nil  // リセット
            }
        }
    }
}
```

---

### パターン B: 書き込み操作があるビュー

**対象**: `AddDreamView`, `AddReflectionView`, `DailyDetailView`

`try-catch` 内で `ErrorLogger` を使用してエラーを処理。

```swift
struct MyWriteView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    var body: some View {
        // ... UI ...
    }
    
    // 保存処理の例
    private func save() {
        Task {
            await MainActor.run { isSaving = true }
            
            // 1. 認証チェック
            guard let userId = authManager.userId else {
                let error = AppError.authenticationRequired
                ErrorLogger.logError(error, context: "MyWriteView.save")
                await MainActor.run {
                    errorMessage = ErrorLogger.userFacingMessage(from: error)
                    showError = true
                    isSaving = false
                }
                return
            }
            
            // 2. 保存処理
            do {
                try await dreamService.saveDream(
                    content: content,
                    recordDate: date,
                    userId: userId
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // 3. エラー処理（3ステップ）
                let appError = ErrorLogger.classify(error, context: .network)
                ErrorLogger.logError(appError, context: "MyWriteView.save")
                await MainActor.run {
                    errorMessage = ErrorLogger.userFacingMessage(from: appError)
                    showError = true
                    isSaving = false
                }
            }
        }
    }
}
```

---

### パターン C: 読み取り + 書き込み両方があるビュー

**対象**: `HomeView`, `DailyDetailView`

パターンAとパターンBを組み合わせます。

```swift
struct MyMixedView: View {
    @EnvironmentObject var dreamService: DreamService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            // ... コンテンツ ...
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        // パターンA: Service監視
        .onChange(of: dreamService.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
                showError = true
                dreamService.errorMessage = nil
            }
        }
    }
    
    // パターンB: 削除処理
    private func deleteDream(_ dream: Dream) async {
        guard let userId = authManager.userId else { return }
        
        do {
            try await dreamService.deleteDream(dream, userId: userId)
        } catch {
            let appError = ErrorLogger.classify(error, context: .network)
            ErrorLogger.logError(appError, context: "MyMixedView.deleteDream")
            await MainActor.run {
                errorMessage = ErrorLogger.userFacingMessage(from: appError)
                showError = true
            }
        }
    }
}
```

---

### パターン D: AI処理があるビュー

**対象**: `AddDreamView`, `AddReflectionView`, `DailyDetailView`

AI処理のエラーは `context: .ai` を使用。

```swift
private func callAI() async {
    do {
        let model = ai.generativeModel(modelName: "gemini-2.5-flash")
        let response = try await model.generateContent(prompt)
        
        if let text = response.text {
            await MainActor.run {
                self.content = text
            }
        } else {
            // AIからの空レスポンスは明示的にエラーとして扱う
            throw AppError.aiServiceError("AIからの応答が空でした。")
        }
    } catch {
        // context: .ai を指定
        let appError = ErrorLogger.classify(error, context: .ai)
        ErrorLogger.logError(appError, context: "MyView.callAI")
        await MainActor.run {
            errorMessage = ErrorLogger.userFacingMessage(from: appError)
            showError = true
        }
    }
}
```

---

## ErrorLoggerの使い方

### 3つのメソッド

| メソッド | 用途 | 使用タイミング |
|---------|------|---------------|
| `classify(error:context:)` | ErrorをAppErrorに変換 | catchブロックの最初 |
| `logError(error:context:)` | OSLogにエラーを記録 | classifyの直後 |
| `userFacingMessage(from:)` | ユーザー向けメッセージ取得 | UI更新時 |

### ErrorContext の選択

| Context | 使用場面 |
|---------|---------|
| `.network` | Firestore操作、API通信 |
| `.ai` | Gemini API呼び出し |
| `.audio` | 音声認識、オーディオセッション |
| `.auth` | 認証処理（Google Sign-In、ログアウト等） |
| `.general` | その他（デフォルト） |

### 標準的な使用パターン

```swift
do {
    try await someAsyncOperation()
} catch {
    // Step 1: 分類
    let appError = ErrorLogger.classify(error, context: .network)
    
    // Step 2: ログ記録
    ErrorLogger.logError(appError, context: "ClassName.methodName")
    
    // Step 3: UI更新
    await MainActor.run {
        errorMessage = ErrorLogger.userFacingMessage(from: appError)
        showError = true
    }
}
```

---

## AppErrorの種類

`Models/AppError.swift` で定義されているエラー型：

| エラー | 説明 | 典型的なcontext |
|--------|------|-----------------|
| `networkError` | ネットワーク/Firestore関連 | `.network` |
| `decodingError` | データ変換エラー | `.network` |
| `authenticationRequired` | 認証が必要 | 直接使用 |
| `aiServiceError` | AI処理エラー | `.ai` |
| `audioSessionError` | 音声セッションエラー | `.audio` |
| `authError` | 認証処理エラー（Google Sign-In等） | `.auth` |
| `unknownError` | 不明なエラー | `.general` |

### 直接AppErrorを使用する場合

認証エラーなど、classifyを通さず直接AppErrorを作成する場合：

```swift
guard let userId = authManager.userId else {
    let error = AppError.authenticationRequired
    ErrorLogger.logError(error, context: "MyView.save")
    errorMessage = ErrorLogger.userFacingMessage(from: error)
    showError = true
    return
}
```

---

## 実装チェックリスト

新しいビューを作成する際のチェックリスト：

### 基本設定
- [ ] `@State private var showError = false` を定義
- [ ] `@State private var errorMessage = ""` を定義
- [ ] `.alert()` モディファイアを追加

### 読み取り機能がある場合
- [ ] `@EnvironmentObject var dreamService: DreamService` を追加
- [ ] `@EnvironmentObject var reflectionService: ReflectionService` を追加（必要に応じて）
- [ ] `.onChange(of: dreamService.errorMessage)` を追加
- [ ] `.onChange(of: reflectionService.errorMessage)` を追加（必要に応じて）

### 書き込み機能がある場合
- [ ] `@EnvironmentObject var authManager: AuthManager` を追加
- [ ] `guard let userId = authManager.userId` で認証チェック
- [ ] `do-catch` で操作を囲む
- [ ] `ErrorLogger.classify()` でエラーを分類
- [ ] `ErrorLogger.logError()` でログ記録
- [ ] `ErrorLogger.userFacingMessage()` でメッセージ取得
- [ ] `await MainActor.run { }` でUI更新

### AI機能がある場合
- [ ] `context: .ai` を使用
- [ ] 空レスポンスのハンドリング

---

## 既存ビューの参照先

| パターン | 参照ビュー | ファイルパス |
|----------|-----------|-------------|
| 読み取りのみ | `AllDreamsView` | `Views/AllDreamsView.swift` |
| 読み取り + 削除 | `HomeView` | `Views/HomeView.swift` |
| 書き込み + AI | `AddDreamView` | `Views/AddDreamView.swift` |
| 読み取り + 削除 + AI | `DailyDetailView` | `Views/DailyDetailView.swift` |

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2024-12-07 | 初版作成 |
