import SwiftUI

// App Entry Point
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
