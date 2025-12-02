import Foundation

/// アプリケーション全体で使用するカスタムエラー型
enum AppError: LocalizedError {
    case authenticationRequired
    case invalidUserId
    case missingDocumentId(String) // ドキュメントタイプ（"夢"、"日記"など）
    case networkError(Error)
    case decodingError(Error)
    case aiServiceError(String)
    case audioSessionError(Error)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "ユーザーがログインしていません"
        case .invalidUserId:
            return "ユーザーIDがありません"
        case .missingDocumentId(let type):
            return "\(type)のIDがありません"
        case .networkError(let error):
            return "ネットワークエラーが発生しました: \(error.localizedDescription)"
        case .decodingError(let error):
            return "データの読み込みに失敗しました: \(error.localizedDescription)"
        case .aiServiceError(let message):
            return "AIサービスのエラー: \(message)"
        case .audioSessionError(let error):
            return "オーディオセッションのエラー: \(error.localizedDescription)"
        case .unknownError(let error):
            return "予期しないエラーが発生しました: \(error.localizedDescription)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .authenticationRequired:
            return "認証が必要です。ログインしてください。"
        case .invalidUserId:
            return "有効なユーザーIDが取得できませんでした。"
        case .missingDocumentId(let type):
            return "\(type)のIDが存在しません。"
        case .networkError(let error):
            return "ネットワークエラーが発生しました。"
        case .decodingError(let error):
            return "データの読み込みに失敗しました。"
        case .aiServiceError(let message):
            return message
        case .audioSessionError(let error):
            return "オーディオセッションの設定に失敗しました。"
        case .unknownError(let error):
            return "予期しないエラーが発生しました。"
        }
    }
    
    /// 基になるエラーを取得（存在する場合）
    var underlyingError: Error? {
        switch self {
        case .networkError(let error),
             .decodingError(let error),
             .audioSessionError(let error),
             .unknownError(let error):
            return error
        default:
            return nil
        }
    }
}

