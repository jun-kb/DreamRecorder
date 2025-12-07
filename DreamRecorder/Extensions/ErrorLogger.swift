import Foundation
import OSLog

/// エラー分類時のデフォルトタイプを指定
enum ErrorContext {
    case network    // Firestore、API通信など
    case ai         // AI処理（Gemini API等）
    case audio      // オーディオセッション
    case general    // 汎用（unknownErrorにフォールバック）
}

/// エラーロギングを一元管理するユーティリティ
struct ErrorLogger {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DreamRecorder", category: "Error")
    
    /// 汎用エラーをAppErrorに分類する
    /// - Parameters:
    ///   - error: 分類するエラー
    ///   - context: エラーが発生したコンテキスト（デフォルトのエラータイプを決定）
    /// - Returns: 適切に分類されたAppError
    static func classify(_ error: Error, context: ErrorContext = .general) -> AppError {
        // すでにAppErrorならそのまま返す
        if let appError = error as? AppError {
            return appError
        }
        
        // URLErrorはネットワークエラーとして分類
        if let urlError = error as? URLError {
            return .networkError(urlError)
        }
        
        // NSErrorのドメインで判定
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            return .networkError(error)
        case NSCocoaErrorDomain where nsError.code == NSFileReadCorruptFileError:
            return .decodingError(error)
        default:
            break
        }
        
        // コンテキストに応じたデフォルト分類
        switch context {
        case .network:
            return .networkError(error)
        case .ai:
            return .aiServiceError(error.localizedDescription)
        case .audio:
            return .audioSessionError(error)
        case .general:
            return .unknownError(error)
        }
    }
    
    /// エラーをログに記録する
    /// - Parameters:
    ///   - error: 記録するエラー
    ///   - context: エラーが発生したコンテキスト（クラス名、メソッド名など）
    static func logError(_ error: Error, context: String = "") {
        let contextPrefix = context.isEmpty ? "" : "[\(context)] "
        
        #if DEBUG
        // デバッグビルドでは詳細情報を記録
        if let appError = error as? AppError {
            logger.error("\(contextPrefix)\(appError.errorDescription ?? "Unknown error")")
            if let failureReason = appError.failureReason {
                logger.debug("\(contextPrefix)Failure reason: \(failureReason)")
            }
            if let underlyingError = appError.underlyingError {
                logger.debug("\(contextPrefix)Underlying error: \(underlyingError.localizedDescription)")
            }
        } else {
            logger.error("\(contextPrefix)\(error.localizedDescription)")
            logger.debug("\(contextPrefix)Error details: \(String(describing: error))")
        }
        #else
        // リリースビルドでは簡潔な情報のみ記録
        if let appError = error as? AppError {
            logger.error("\(contextPrefix)\(appError.errorDescription ?? "Unknown error")")
        } else {
            logger.error("\(contextPrefix)\(error.localizedDescription)")
        }
        #endif
    }
    
    /// エラーメッセージを文字列として取得（UI表示用）
    /// - Parameter error: エラー
    /// - Returns: ユーザー向けのエラーメッセージ
    static func userFacingMessage(from error: Error) -> String {
        if let appError = error as? AppError {
            return appError.errorDescription ?? "エラーが発生しました"
        }
        return error.localizedDescription
    }
}

