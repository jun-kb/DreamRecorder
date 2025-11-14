import SwiftUI

// Helper Extension (TextEditorのプレースホルダー用)
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
