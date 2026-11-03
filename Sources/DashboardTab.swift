import SwiftUI

struct DashboardTab: View {
    let student: StudentProfile
    let editProfile: () -> Void
    private var plan: StudentLearningPlan { StudentLearningPlanTemplates.forStudent(student.id, subject: student.subjects.first ?? "Mathematics") }
    private var progress: [SubjectProgress] {
        student.subjects.flatMap { StudentLearningPlanTemplates.forStudent(student.id, subject: $0).progress }.prefix(6).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("STUDENT OVERVIEW")
                        .font(.caption.weight(.bold)).tracking(1.1)
                        .foregroundStyle(.white.opacity(0.72))
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(student.name).font(.largeTitle.bold())
                            Text("Age \(student.age.map(String.init) ?? "not set") · \(student.gradeLevel) · " + student.subjects.joined(separator: ", "))
                                .font(.subheadline).foregroundStyle(.white.opacity(0.78))
                        }
                        Spacer()
                        Button(action: editProfile) {
                            Image(systemName: "square.and.pencil")
                                .font(.headline).foregroundStyle(.white)
                                .padding(10).background(.white.opacity(0.15), in: Circle())
                        }
                        .accessibilityLabel("Edit student profile")
                    }
                    Text(student.summary)
                        .font(.body).foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 5)
                }
                .padding(22)
                .foregroundStyle(.white)
                .background(LinearGradient(colors: [.indigo, Color(red: 0.12, green: 0.16, blue: 0.38)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))

                HStack {
                    Text("Subject progress").font(.title2.bold())
                    Spacer()
                    Text(plan.month).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                }
                ForEach(progress) { item in ProgressRow(progress: item) }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Next milestone", systemImage: "sparkles")
                        .font(.headline).foregroundStyle(.indigo)
                    Text(plan.milestones.first?.title ?? "Keep learning")
                        .font(.title3.bold())
                    Text(plan.milestones.first?.date ?? "")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.quaternary))
            }
            .padding(20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
