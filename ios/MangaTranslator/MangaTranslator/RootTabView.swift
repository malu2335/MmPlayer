import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("漫画库", systemImage: "books.vertical") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
