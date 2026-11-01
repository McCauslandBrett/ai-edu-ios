import SwiftUI

@main
struct AIEduApp: App {
    @StateObject private var documents = AssignmentDocumentStore()
    @StateObject private var profiles = StudentProfileStore()

    var body: some Scene {
        WindowGroup {
            LearningHubView()
                .environmentObject(documents)
                .environmentObject(profiles)
        }
    }
}
