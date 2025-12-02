# セキュリティ上の懸念事項

このドキュメントは、DreamRecorderプロジェクトにおけるセキュリティ上の懸念事項をまとめたものです。

## 🔴 重大な懸念事項

### 1. 機密情報のリポジトリへのコミット

**問題:**
- `GoogleService-Info.plist` ファイルがリポジトリに含まれている可能性があります
- このファイルには以下の機密情報が含まれています：
  - Firebase API Key: `AIzaSyDFTeA9eDHNdNJclJWw9dNycY4amC6ndfY`
  - Google App ID: `1:282073110561:ios:31b6e511054d49f1296b60`
  - Project ID: `dreamrecoder-cb2ef`
  - Storage Bucket: `dreamrecoder-cb2ef.firebasestorage.app`

**影響:**
- 悪意のあるユーザーがAPIキーを悪用し、Firebaseプロジェクトに不正アクセスする可能性
- コストの不正利用やデータの不正取得のリスク
- プロジェクト全体のセキュリティ侵害

**推奨される対応:**
1. 即座に `GoogleService-Info.plist` をGit履歴から削除（`git filter-branch` または `git filter-repo` を使用）
2. Firebase ConsoleでAPIキーを無効化し、新しいキーを生成
3. `.gitignore` に既に含まれていることを確認し、今後コミットされないようにする
4. 既に公開リポジトリにプッシュしている場合は、Firebaseプロジェクトの設定を再確認

### 2. Firestoreセキュリティルールの未確認

**問題:**
- Firestoreのセキュリティルールファイル（`firestore.rules`）がプロジェクト内に見つかりません
- クライアント側の認証チェックのみに依存している可能性があります

**影響:**
- クライアント側の認証チェックをバイパスされた場合、不正なデータアクセスが可能になる可能性
- ユーザーが他のユーザーのデータにアクセスできる可能性
- データの改ざんや削除が可能になる可能性

**推奨される対応:**
1. Firestore Consoleでセキュリティルールを確認・設定
2. 以下のようなルールを実装することを推奨：
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
         
         match /dreams/{dreamId} {
           allow read, write: if request.auth != null && request.auth.uid == userId;
         }
         
         match /reflections/{reflectionId} {
           allow read, write: if request.auth != null && request.auth.uid == userId;
         }
       }
     }
   }
   ```
3. セキュリティルールファイルをプロジェクトに含め、バージョン管理する

## 🟡 中程度の懸念事項

### 3. 匿名認証のみの使用

**問題:**
- `AuthManager.swift` では匿名認証のみが実装されています
- ユーザーの永続的な識別が困難です

**影響:**
- デバイスを変更したりアプリを再インストールすると、データにアクセスできなくなる
- ユーザーが自分のデータを復元できない
- セキュリティ監査や不正行為の追跡が困難

**推奨される対応:**
1. オプションとして、メール/パスワード認証やOAuth認証を追加
2. 匿名認証を永続的な認証にリンクする機能を実装
3. ユーザーに認証方法の選択肢を提供

### 4. クライアント側のみの認証チェック

**問題:**
- `DreamService.swift` と `ReflectionService.swift` では、`userId` の検証がクライアント側でのみ行われています
- サーバー側（Firestore）での認証検証が確認できません

**影響:**
- クライアント側のコードを改ざんされた場合、他のユーザーのデータにアクセスできる可能性
- 不正なリクエストがサーバーに到達する可能性

**推奨される対応:**
1. 上記のFirestoreセキュリティルールを実装（最重要）
2. クライアント側のチェックはUX向上のため残しつつ、サーバー側の検証を必須とする
3. 認証トークンの検証を確実に行う

### 5. AIプロンプトインジェクションのリスク

**問題:**
- `DreamService.swift` の `interpretDream` メソッドで、ユーザー入力（`dream.content`）が直接AIプロンプトに含まれています
- プロンプトインジェクション攻撃の可能性があります

**影響:**
- 悪意のあるユーザーがプロンプトを操作し、AIの動作を変更できる可能性
- 不適切なコンテンツの生成
- システムプロンプトの漏洩

**推奨される対応:**
1. ユーザー入力をサニタイズ（エスケープ）する
2. プロンプトテンプレートを使用し、ユーザー入力を明確に分離する
3. 入力長の制限を設ける
4. 不適切なコンテンツのフィルタリングを実装

### 6. エラーメッセージからの情報漏洩

**問題:**
- エラーメッセージに詳細な技術情報が含まれる可能性があります
- `SignInView.swift` で `print` ステートメントが使用されています

**影響:**
- デバッグ情報がログに残り、システムの内部構造が漏洩する可能性
- 攻撃者に有用な情報を提供する可能性

**推奨される対応:**
1. 本番環境では詳細なエラーメッセージをユーザーに表示しない
2. デバッグ用の `print` ステートメントを削除または条件付きコンパイルで無効化
3. エラーログは適切なロギングサービスに送信し、ユーザーには汎用的なメッセージを表示

## 🟢 軽微な懸念事項

### 7. 音声認識の権限管理

**現状:**
- `SpeechRecognizerManager.swift` では適切に権限要求が実装されています

**改善提案:**
- 権限が拒否された場合のフォールバック機能を検討
- 権限の状態を定期的に確認する仕組みを追加

### 8. データの暗号化

**問題:**
- 機密性の高い夢の記録や振り返り日記が、Firestoreに平文で保存されている可能性があります

**推奨される対応:**
1. クライアント側での暗号化を検討（特に機密性の高いデータ）
2. Firestoreの暗号化設定を確認
3. 転送時の暗号化（TLS）はFirebaseが自動的に提供

### 9. 入力検証の不足

**問題:**
- ユーザー入力の長さや形式の検証が不十分な可能性があります

**推奨される対応:**
1. 入力長の制限を実装
2. 不正な文字列のフィルタリング
3. XSS攻撃を防ぐためのサニタイゼーション（Webビューを使用する場合）

## 📋 セキュリティチェックリスト

- [ ] `GoogleService-Info.plist` をGit履歴から削除
- [ ] Firebase APIキーを再生成
- [ ] Firestoreセキュリティルールを実装・確認
- [ ] 匿名認証から永続的な認証への移行を検討
- [ ] AIプロンプトのサニタイゼーションを実装
- [ ] エラーメッセージの見直し
- [ ] デバッグ用の `print` ステートメントを削除
- [ ] 入力検証の強化
- [ ] セキュリティ監査の実施
- [ ] 定期的なセキュリティレビューの実施

## 🔗 参考リソース

- [Firebase Security Rules](https://firebase.google.com/docs/rules)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [iOS App Security Best Practices](https://developer.apple.com/documentation/security)

---

**最終更新日:** 2024年
**レビュー担当者:** 要確認

