import Foundation
import OSLog

/// エラーロギングを一元管理するユーティリティ
struct ErrorLogger {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DreamRecorder", category: "Error")
    
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

