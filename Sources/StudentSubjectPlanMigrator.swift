import Foundation

struct StudentSubjectPlanMigration {
    let plans: [String: StudentSubjectPlan]
    let subjectRenames: [String: [String: String]]
    let didChange: Bool
}

/// Applies versioned transformations to persisted prebuilt subject plans.
enum StudentSubjectPlanMigrator {
    static func migrate(
        _ existingPlans: [String: StudentSubjectPlan],
        planBuilder: any PrebuiltSubjectPlanBuilding = PrebuiltSubjectPlanBuilder()
    ) -> StudentSubjectPlanMigration {
        var plans = existingPlans
        var subjectRenames: [String: [String: String]] = [:]
        var didChange = false

        for (key, existing) in existingPlans {
            guard let prebuiltID = existing.prebuiltSubjectID,
                  let curriculum = PrebuiltSubject.catalog.first(where: { $0.id == prebuiltID }),
                  (existing.prebuiltContentVersion ?? 0) < curriculum.contentVersion else {
                continue
            }

            let generated = planBuilder.build(
                subject: curriculum,
                studentID: existing.studentID,
                subjectName: existing.subject,
                planInstanceID: existing.planInstanceID
            )
            let plan = GeneratedLearningPlan(
                subject: generated.plan.subject,
                objective: generated.plan.objective,
                monthlyWindow: generated.plan.monthlyWindow,
                milestones: generated.plan.milestones,
                progress: existing.plan.progress.isEmpty ? generated.plan.progress : existing.plan.progress,
                weeks: generated.plan.weeks
            )
            let updated = StudentSubjectPlan(
                studentID: existing.studentID,
                subject: generated.subject,
                inputs: existing.inputs,
                plan: plan,
                prebuiltSubjectID: existing.prebuiltSubjectID,
                prebuiltContentVersion: curriculum.contentVersion,
                planInstanceID: existing.planInstanceID,
                competencyResults: existing.competencyResults
            )
            plans.removeValue(forKey: key)
            plans[updated.id] = updated
            if existing.subject.caseInsensitiveCompare(updated.subject) != .orderedSame {
                subjectRenames[existing.studentID, default: [:]][existing.subject] = updated.subject
            }
            didChange = true
        }

        return StudentSubjectPlanMigration(plans: plans, subjectRenames: subjectRenames, didChange: didChange)
    }

}
