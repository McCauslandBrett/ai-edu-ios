import Foundation
import Combine
import PencilKit

@MainActor
final class AssignmentDocumentStore: ObservableObject {
    @Published private(set) var drawings: [String: PKDrawing] = [:]
    @Published private(set) var savingAssignments: Set<String> = []

    private var pendingSaves: [String: DispatchWorkItem] = [:]

    func drawing(for assignmentID: String) -> PKDrawing {
        if let drawing = drawings[assignmentID] {
            return drawing
        }
        let loaded = loadDrawing(for: assignmentID)
        drawings[assignmentID] = loaded
        return loaded
    }

    func updateDrawing(_ drawing: PKDrawing, for assignmentID: String) {
        drawings[assignmentID] = drawing
        savingAssignments.insert(assignmentID)
        scheduleSave(drawing, for: assignmentID)
    }

    private func scheduleSave(_ drawing: PKDrawing, for assignmentID: String) {
        pendingSaves[assignmentID]?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.write(drawing, for: assignmentID)
        }
        pendingSaves[assignmentID] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func flushSave(for assignmentID: String) {
        pendingSaves[assignmentID]?.cancel()
        if let drawing = drawings[assignmentID] {
            write(drawing, for: assignmentID)
        }
    }

    func status(for assignmentID: String) -> String {
        savingAssignments.contains(assignmentID) ? "Saving…" : "Saved on this iPad"
    }

    func deleteWork(for assignmentID: String) {
        pendingSaves[assignmentID]?.cancel()
        pendingSaves.removeValue(forKey: assignmentID)
        drawings.removeValue(forKey: assignmentID)
        savingAssignments.remove(assignmentID)
        removeSavedDrawing(for: assignmentID)
    }

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AssignmentWork", isDirectory: true)
    }

    private func fileURL(for assignmentID: String) -> URL {
        let safeID = assignmentID.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? String($0) : "_"
        }.joined()
        return documentsDirectory.appendingPathComponent("\(safeID).drawing")
    }

    private func loadDrawing(for assignmentID: String) -> PKDrawing {
        guard let data = try? Data(contentsOf: fileURL(for: assignmentID)),
              let drawing = try? PKDrawing(data: data) else {
            return PKDrawing()
        }
        return drawing
    }

    private func write(_ drawing: PKDrawing, for assignmentID: String) {
        do {
            try FileManager.default.createDirectory(
                at: documentsDirectory,
                withIntermediateDirectories: true
            )
            try drawing.dataRepresentation().write(to: fileURL(for: assignmentID), options: .atomic)
            savingAssignments.remove(assignmentID)
        } catch {
            savingAssignments.insert(assignmentID)
        }
    }

    private func removeSavedDrawing(for assignmentID: String) {
        try? FileManager.default.removeItem(at: fileURL(for: assignmentID))
    }
}
