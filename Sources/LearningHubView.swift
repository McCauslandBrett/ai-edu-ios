import SwiftUI

struct LearningHubView: View {
    @EnvironmentObject private var profiles: StudentProfileStore
    @EnvironmentObject private var documents: AssignmentDocumentStore
    @State private var showingAddStudent = false
    @State private var editingProfile: StudentProfile?
    private let gradeStore = AssignmentGradeStore()

    private var student: StudentProfile { profiles.selectedStudent }

    var body: some View {
        TabView {
            NavigationStack {
                DashboardTab(student: student, editProfile: { editingProfile = student })
                    .navigationTitle("Learning AI")
                    .toolbar { studentPicker }
            }
            .tabItem { Label("Dashboard", systemImage: "house") }

            NavigationStack {
                SubjectsTab(student: student)
                    .navigationTitle("Subjects")
                    .toolbar { studentPicker }
            }
            .tabItem { Label("Subjects", systemImage: "square.grid.2x2") }

            NavigationStack {
                AssignmentListTab(student: student)
                    .navigationTitle("Assignments")
                    .toolbar { studentPicker }
            }
            .tabItem { Label("Assignments", systemImage: "doc.text") }

            NavigationStack {
                ProfileTab(student: student, onEdit: { editingProfile = student })
                    .navigationTitle("Profile")
                    .toolbar {
                        studentPicker
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showingAddStudent = true } label: { Image(systemName: "person.badge.plus") }
                                .accessibilityLabel("Add student")
                        }
                    }
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(.indigo)
        .sheet(isPresented: $showingAddStudent) {
            ProfileEditor(profile: nil) { profiles.save($0) }
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditor(
                profile: profile,
                canDeleteStudent: profiles.students.count > 1,
                onDelete: deleteStudent
            ) { profiles.save($0) }
        }
    }

    private func deleteStudent(_ profile: StudentProfile) {
        removeStoredWork(for: profile)
        profiles.deleteStudent(studentID: profile.id)
    }

    private func removeStoredWork(for profile: StudentProfile) {
        let ownedAssignments = profiles.assignments(for: profile).filter { $0.studentID == profile.id }
        for assignment in ownedAssignments {
            removeStoredWork(for: assignment)
        }
    }

    private func removeStoredWork(for assignment: Assignment) {
        gradeStore.delete(assignmentID: assignment.id)
        documents.deleteWork(for: assignment.id)
    }

    @ToolbarContentBuilder
    private var studentPicker: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(profiles.students) { item in
                    Button {
                        profiles.selectedStudentID = item.id
                    } label: {
                        if item.id == student.id {
                            Label(item.name, systemImage: "checkmark")
                        } else {
                            Text(item.name)
                        }
                    }
                }
                Divider()
                Button { showingAddStudent = true } label: {
                    Label("Add student", systemImage: "person.badge.plus")
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "person.crop.circle.fill")
                    Text(student.name.components(separatedBy: " ").first ?? student.name)
                }
                .font(.subheadline.weight(.medium))
            }
            .accessibilityLabel("Selected student: \(student.name)")
        }
    }
}
