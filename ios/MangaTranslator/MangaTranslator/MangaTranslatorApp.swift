import SwiftUI

@main
struct MangaTranslatorApp: App {
    init() {
        _ = OcrModelPaths.resolvedRootDirectory()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
