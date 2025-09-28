import Foundation

class PhoneSessionManager: ObservableObject {
    @Published var files: [URL] = []
    var allFiles: [URL] = []

    func reloadFiles() {
        let manager = FileManager.default
        guard let docDir = manager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            files = []
            allFiles = []
            return
        }
        let fetched = (try? manager.contentsOfDirectory(at: docDir, includingPropertiesForKeys: nil)) ?? []
        allFiles = fetched
        files = fetched.sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
    }

    func deleteSessionFiles(sessionFileList: [String]) {
        for fname in sessionFileList {
            if let url = allFiles.first(where: { $0.lastPathComponent == fname }) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        reloadFiles()
    }

    func deleteFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        reloadFiles()
    }
    
    func clearAllFiles() {
        for url in files {
            try? FileManager.default.removeItem(at: url)
        }
        reloadFiles()
    }
}
