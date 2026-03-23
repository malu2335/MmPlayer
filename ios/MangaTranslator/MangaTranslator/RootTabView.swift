import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("漫画库", systemImage: "books.vertical") }
            QuickTranslateView()
                .tabItem { Label("快速翻译", systemImage: "bolt.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
