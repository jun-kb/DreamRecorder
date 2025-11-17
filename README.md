# ビルドと実行の手順

## 1\. リポジトリのクローン

まず、このプロジェクトをローカル環境にクローンします。

```bash
git clone https://github.com/your-username/DreamRecorder.git
```

```bash
cd DreamRecorder
```

## 2\. プロジェクトファイルの設定

1.  ジュンジュンから、`GoogleService-Info.plist` ファイルを貰います。

2.  貰った `GoogleService-Info.plist` ファイルを、Xcodeプロジェクトの `DreamRecorder/` フォルダ（`DreamRecorderApp.swift` と同じ階層）にドラッグ＆ドロップで追加します。

    ```
    DreamRecorder/
    ├── DreamRecorderApp.swift
    ├── GoogleService-Info.plist  <-- (ここに配置)
    ├── Info.plist
    ├── Assets.xcassets
    └── ...
    ```

    *(注: `GoogleService-Info.plist` はAPIキーを含むため、リポジトリの `.gitignore` によって意図的にバージョン管理から除外されています)*

## 3\. Xcodeでのビルド

1.  ターミナルから `DreamRecorder.xcodeproj` ファイルを開きます。
    ```bash
    open DreamRecorder.xcodeproj
    ```
2.  Xcodeが自動的にSwift Packageの依存関係（`FirebaseAI`, `FirebaseAuth`, `FirebaseFirestore` など）を解決するのを待ちます。
3.  実行するターゲット（シミュレータまたはUSBで接続した実機）を選択します。
4.  **Run** ボタン（▶︎）を押すか、 `Cmd + R` を押してビルドと実行を行います。
