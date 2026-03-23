import SwiftUI

struct LibraryView: View {
    @StateObject private var model = LibraryViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.folders, id: \.path) { url in
                    NavigationLink(value: url) {
                        HStack {
                            Text(url.lastPathComponent)
                            Spacer()
                            let n = model.repository.listImages(in: url).count
                            Text("\(n) 张")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: model.deleteFolders)
            }
            .navigationTitle("漫画库")
            .navigationDestination(for: URL.self) { folder in
                FolderDetailView(folder: folder, library: model)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("新建文件夹", systemImage: "folder.badge.plus") {
                        model.showNewFolder = true
                    }
                }
            }
            .alert("新建文件夹", isPresented: $model.showNewFolder) {
                TextField("名称", text: $model.newFolderName)
                Button("取消", role: .cancel) { model.newFolderName = "" }
                Button("创建") { model.createFolder() }
            } message: {
                Text("文件夹将保存在应用沙盒的 Application Support 中。")
            }
            .onAppear { model.refresh() }
        }
    }
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var folders: [URL] = []
    @Published var showNewFolder = false
    @Published var newFolderName = ""

    let repository = LibraryRepository()

    func refresh() {
        folders = repository.listFolders()
    }

    func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        _ = repository.createFolder(name: name)
        newFolderName = ""
        showNewFolder = false
        refresh()
    }

    func deleteFolders(at offsets: IndexSet) {
        for i in offsets {
            let url = folders[i]
            try? repository.deleteFolder(at: url)
        }
        refresh()
    }
}
