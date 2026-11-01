import SwiftUI

@main
struct AIEduApp: App {
    @StateObject private var documents = AssignmentDocumentStore()

    var body: some Scene {
        WindowGroup {
            AssignmentListView()
                .environmentObject(documents)
        }
    }
}
