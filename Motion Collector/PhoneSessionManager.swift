import Foundation
import WatchConnectivity

struct MotionFile: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var url: URL

    static func ==(lhs: MotionFile, rhs: MotionFile) -> Bool {
        lhs.url == rhs.url
    }
}

class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var files: [MotionFile] = []

    override init() {
        super.init()
        loadFiles()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// Loads all CSV files from the Documents directory
    func loadFiles() {
        files.removeAll()
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil)
            for url in fileURLs where url.pathExtension.lowercased() == "csv" {
                files.append(MotionFile(name: url.lastPathComponent, url: url))
            }
        } catch {
            print("Error loading files: \(error)")
        }
    }

    /// Adds a new file to the files array if not already present
    func addFile(url: URL) {
        if !files.contains(where: { $0.url == url }) {
            files.append(MotionFile(name: url.lastPathComponent, url: url))
        }
    }

    /// Renames a file and updates the files array
    func rename(file: MotionFile, to newName: String) {
        let safeName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeName.isEmpty else { return }
        let newFileName = safeName + ".csv"
        let newURL = file.url.deletingLastPathComponent().appendingPathComponent(newFileName)
        do {
            try FileManager.default.moveItem(at: file.url, to: newURL)
            if let idx = files.firstIndex(where: { $0.id == file.id }) {
                files[idx].name = newFileName
                files[idx].url = newURL
            }
        } catch {
            print("Rename failed: \(error)")
        }
    }

    /// Deletes a file and updates the files array
    func delete(file: MotionFile) {
        do {
            try FileManager.default.removeItem(at: file.url)
            files.removeAll { $0.id == file.id }
        } catch {
            print("Delete failed: \(error)")
        }
    }

    // MARK: - WCSessionDelegate required methods

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Required but not used on iPhone
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // Required but not used on iPhone
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Required but not used on iPhone
    }

    /// Receives a file from the Watch, moves it to Documents, and updates the files array
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destURL = docsURL.appendingPathComponent(file.fileURL.lastPathComponent)
        do {
            // Remove existing file if needed
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: file.fileURL, to: destURL)
            DispatchQueue.main.async {
                self.addFile(url: destURL)
            }
        } catch {
            print("Failed to move received file: \(error)")
        }
    }

    /// Call this onAppear to reload files if needed
    func setup() {
        loadFiles()
    }
}
