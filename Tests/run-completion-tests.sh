#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/aiedu-completion-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
swiftc -module-cache-path "$test_dir/module-cache" \
  Sources/Assignment.swift Sources/AssignmentAIModels.swift \
  Sources/StudentProfile.swift Sources/StudentSubjectPlan.swift \
  Sources/StudentLearningPlan.swift Sources/LearningPlanModels.swift \
  Sources/MEPCurriculumPlanBuilder.swift Sources/StudentAssignmentCatalog.swift \
  Sources/SubjectCompetencyTracker.swift Sources/StudentProfilePersistence.swift \
  Sources/StudentProfileStore.swift Tests/AssignmentCompletionTests.swift \
  -o "$test_dir/tests"
"$test_dir/tests"
