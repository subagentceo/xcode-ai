# XcodeAI Extension

Xcode 26 Source Editor Extension connecting to coworkers-agent Worker.

## Commands
- Explain Selected Code
- Refactor Selected Code  
- Generate Unit Tests
- Fix Bug / Suggest Fix
- Add Documentation Comments
- Code Review (Inline Comments)
- Translate to Swift 6

## Setup
1. Open `XcodeAI.xcodeproj` in Xcode 26
2. Sign in to CoworkersNative iOS app first (shares session via App Group)
3. Enable extension: Xcode → Settings → Extensions → XcodeAI
4. Select code → Editor → XcodeAI → choose command

## Auth
Reads session from App Group `group.com.managedcoworkers.native`
Set by CoworkersNative iOS app after login.
No separate login needed if CoworkersNative is installed.