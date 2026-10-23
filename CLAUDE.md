# NextCall

macOS menu bar app that shows upcoming meetings and joins calls in one click. Spec: `docs/PRD.md` (FR-xx IDs are the source of truth). Build plan and progress: `docs/PLAN.md`. Both files are private: they are kept on the maintainer's Mac and listed in `.gitignore`, so they are not in the repository.

## Constraints (non-negotiable)
- Swift 6, strict concurrency, warnings are errors. SwiftUI for UI; AppKit only where SwiftUI falls short.
- macOS 14.0 minimum, universal binary. Agent app (`LSUIElement`), no Dock icon.
- Menu bar = `NSStatusItem` + `NSPopover` hosting SwiftUI (not `MenuBarExtra`).
- EventKit via `requestFullAccessToEvents()`. UserNotifications with Join/Snooze actions. Launch at login via `SMAppService.mainApp`.
- State: `@Observable`, async/await, `@MainActor` for UI; no Combine unless bridging NotificationCenter.
- Persistence: `@AppStorage` plus one Codable settings blob in UserDefaults. No Core Data.
- SPM deps allowed: KeyboardShortcuts, Sparkle. Ask before adding anything else.
- App Sandbox + Hardened Runtime; entitlements: calendars, network client.
- Logging with `os.Logger` (`Log.*` in NextCallCore); no `print()`.
- Never block the main thread, never poll; idle CPU near zero.
- All user-facing strings in `Resources/Localizable.xcstrings` (en + uk). Every control has an accessibility label.
- Identity: bundle prefix `com.frdzhv`, git author `frdzhv`. Nothing company-related.

## Build and test
```
xcodegen generate
xcodebuild -scheme NextCall -destination 'platform=macOS' build
xcodebuild -scheme NextCall -destination 'platform=macOS' test -only-testing:NextCallCoreTests
```
The `.xcodeproj` is generated from `project.yml` and not committed.
