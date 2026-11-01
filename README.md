# AI Edu iOS

Native SwiftUI proof of concept for reviewing assignments and saving handwritten work on iPad.

## Open the app

Open `AIEdu.xcodeproj` in Xcode, select the `AIEdu` scheme, then choose an iPad simulator or connected iPad and press Run.

## Current proof of concept

- Sample assignment list and assignment detail
- Native PencilKit writing canvas, including Apple Pencil and finger input
- Per-assignment drawing persistence in the app's Documents directory
- Reopening an assignment restores its saved writing

Handwriting stays on the device. Agent grading and server synchronization are not wired up yet.
