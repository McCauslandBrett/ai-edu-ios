# AI Edu iOS

Native SwiftUI learning app for student profiles, subject plans, assignments, and handwritten work on iPad.

## Open the app

Open `AIEdu.xcodeproj` in Xcode, select the `AIEdu` scheme, choose an iPad simulator or connected iPad, and press Run.

## Architecture

- `LearningHubView.swift` owns app navigation and student selection.
- `DashboardTab.swift`, `SubjectsTab.swift`, `SubjectPlanView.swift`, `SubjectPlanCreationView.swift`, `AssignmentListTab.swift`, and `ProfileViews.swift` contain feature views.
- `StudentProfile.swift`, `StudentLearningPlan.swift`, and `StudentSubjectPlan.swift` contain profile and plan models. `StudentLearningPlanTemplates.swift` contains preview data.
- `StudentProfileStore.swift` manages profile/plan state; `StudentProfilePersistence.swift` owns UserDefaults persistence.
- `Assignment.swift`, `AssignmentDocumentStore.swift`, and `AssignmentGradeStore.swift` own assignment data and local work/grade storage.
- `AssignmentGradingService.swift`, `AssignmentGenerationService.swift`, and `LearningPlanGenerationService.swift` own their API operations. `LearningAIHTTPClient.swift` owns HTTP transport, and `HandwritingImageEncoder.swift` prepares PencilKit images for grading.

The AI service lives in `/Users/brettmccausland/Documents/GitHub/ai-edu-service`. The Xcode project uses an explicit source file list, so new Swift files must be registered in `AIEdu.xcodeproj/project.pbxproj`.
