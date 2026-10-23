# NextCall

A native macOS menu bar app that shows your next meetings and joins any video call in one click. It reads the
calendars already set up on your Mac (iCloud, Google, Exchange, and so on), finds the meeting link in each
event, and opens it in the native app or your browser. No accounts, no servers, no analytics.

> Screenshots coming soon. Placeholders for the final release:
>
> | Popover | Menu bar countdown | Full-screen alert | Settings |
> | --- | --- | --- | --- |
> | `docs/images/popover.png` | `docs/images/menu-bar.png` | `docs/images/alert.png` | `docs/images/settings.png` |

## Features

- **One-click join** from the popover, the menu bar menu, a notification, a global hotkey or the full-screen alert.
- **Link detection** for 21 providers (Zoom, Google Meet, Microsoft Teams, Webex, Slack Huddle, FaceTime, Jitsi,
  Whereby, GoTo, Chime, RingCentral, BlueJeans, Discord, Skype, Around, Zoho, Livestorm, Gather, Pop, Tuple,
  Dialpad). It reads the event URL, location and notes (including HTML) and unwraps Outlook SafeLinks,
  `google.com/url` and Proofpoint redirects.
- **Menu bar status**: icon only, a countdown ("in 12m") or title and countdown; accent-coloured in the last five
  minutes and "now" while a meeting runs.
- **Reminders** with Join and Snooze buttons, and an optional **full-screen alert** at the start time that dims the screen behind it so you notice it.
- **Smart filtering**: personal blocks (solo events, "Free" events, titles such as "Lunch" or "Focus") are
  dimmed or hidden and never trigger a reminder; an event with a meeting link always counts as a meeting.
- **Per-provider open mode** (native app or browser) and a choice of browser.
- English and Ukrainian, VoiceOver, full keyboard navigation, Reduce Motion / Transparency / Increase Contrast.

## Download

Get the latest `NextCall-<version>.dmg` from the **Releases** page of this repository, open it and drag NextCall
to Applications. You do not need to clone anything.

The download is not signed with an Apple Developer ID or notarized, so macOS blocks it the first time:

1. Open NextCall once; macOS says it cannot verify the app.
2. Open System Settings > Privacy & Security, scroll down and click **Open Anyway** next to NextCall, then confirm.

Or, from Terminal, once after copying the app to Applications:

```bash
xattr -dr com.apple.quarantine /Applications/NextCall.app
```

Check the download against its `.sha256` file with `shasum -a 256 -c NextCall-<version>.dmg.sha256` in the folder
that holds both. This build does not update itself; download the next release to upgrade. If you would rather
not run an unsigned app, build it from source (below).

## Requirements

- macOS 14 Sonoma or later (Apple Silicon and Intel).
- To build: Xcode 16 or later (developed with Xcode 27) and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  (`brew install xcodegen`).

## Build and run

The Xcode project is generated from `project.yml` and is not committed.

```bash
xcodegen generate
xcodebuild -scheme NextCall -destination 'platform=macOS' build
```

Open `NextCall.xcodeproj` in Xcode to run from there, or launch the built app from DerivedData. Debug builds are
ad-hoc signed, so macOS asks for calendar and notification access again after a rebuild.

### Tests

```bash
# Unit tests: link detection fixtures, scheduling, launching, filtering, settings (fast, no permissions)
xcodebuild -scheme NextCall -destination 'platform=macOS' test -only-testing:NextCallCoreTests

# Everything, including the UI tests (they drive the real popover, settings, alert and onboarding)
xcodebuild -scheme NextCall -destination 'platform=macOS' test

# Every user-facing string must be translated (run after a build)
python3 scripts/check_localization.py
```

The UI tests launch a Debug build with `-uiTestFixtures`: a fixed fake calendar, a pasteboard standing in for the
browser and an in-memory login item. They never touch your calendar, browser or login items, and the fixtures are
compiled out of Release builds. UI tests may need the Xcode test runner to be allowed to control your Mac (System Settings >
Privacy & Security > Accessibility / Automation); macOS prompts for it on the first run.

## Permissions

| Permission | Why | If you say no |
| --- | --- | --- |
| **Calendars** (full access) | To read your events and find their meeting links. EventKit only offers read access together with full access. Nothing is written, and nothing leaves your Mac. | The popover shows a button that opens System Settings. |
| **Notifications** | Reminders before a meeting, with Join and Snooze. Optional. | No reminders; everything else works. |
| **Login item** | Only if you turn on "Launch at login". | The app starts when you open it. |
| **Network** | Only the optional Sparkle update check (direct download builds). | No automatic updates. |

The app runs in the App Sandbox with the Hardened Runtime. Its entitlements are calendars, outgoing network
connections (updates only) and the two Mach lookups Sparkle's installer needs. Google or Outlook calendars show up
once you add the account in System Settings > Internet Accounts.

## Keyboard

| Where | Keys |
| --- | --- |
| Anywhere | Control-Option-N opens the popover, Control-Option-J joins the next meeting (both editable in Settings > Shortcuts) |
| Popover | Up / Down select a meeting, Return joins it, Command-, opens Settings, Esc closes |
| Full-screen alert | Return joins, Esc dismisses |

## Project layout

```
project.yml            XcodeGen spec (targets: NextCall, NextCallCore, NextCallCoreTests, NextCallUITests)
App/                   Entry point, AppDelegate, AppState (single source of truth), notification and update glue
MenuBar/               NSStatusItem controller and menu bar text
Popover/               Popover, header, meeting rows, keyboard navigation
Settings/              Settings window and its tabs
Onboarding/            First-launch flow
Alerts/                Full-screen alert panel
Core/                  NextCallCore framework: all non-UI logic, runs headless in tests
  Calendar/            EventKit wrapper, Meeting models, list building, change monitoring
  LinkDetection/       Detector, provider registry (data), redirect unwrapping, native URL builders
  Filtering/           Meeting vs personal-block rules
  Scheduling/          Timeline, minute-aligned scheduler, reminders, full-screen alert tracker
  Launching/           Joining (native app / browser), launch at login, browser catalog
  Settings/            Codable settings blob stored in UserDefaults
Resources/             Localizable.xcstrings (en, uk), InfoPlist.xcstrings, app icon
Tests/                 Unit tests, 92 link-detection fixtures (Tests/Fixtures), UI tests
scripts/               release.sh, check_localization.py
```

Views never touch EventKit: they read `AppState`, which is fed by `CalendarService` (an actor over a
`CalendarDataSource` seam), `MeetingScheduler` (a minute-aligned timer with an injectable clock) and
`SettingsStore`. Nothing polls: updates come from `EKEventStoreChanged`, wake, day-change and time-zone
notifications, and the scheduler sleeps until the next minute boundary, or not at all when nothing is coming up.

Adding a provider is a data change in `Core/LinkDetection/ProviderRegistry.swift` plus a fixture in
`Tests/Fixtures/link-detection.json`.

## Releasing

`scripts/release.sh` builds a universal Release archive, signs it with Developer ID, notarizes and staples the app,
builds a signed, notarized DMG and generates the Sparkle appcast. Everything secret comes from the environment:

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="nextcall-notary"        # xcrun notarytool store-credentials nextcall-notary ...
export SPARKLE_PUBLIC_ED_KEY="..."             # printed by Sparkle's generate_keys (the private key stays in your keychain)
export SPARKLE_FEED_URL="https://example.com/nextcall/appcast.xml"
export DOWNLOAD_URL_PREFIX="https://example.com/nextcall/releases/"
./scripts/release.sh
```

Results land in `dist/` (`dist/releases/NextCall-<version>.dmg`, `dist/appcast.xml`). Keep old DMGs in
`dist/releases/` so the appcast still lists them. `./scripts/release.sh --dry-run` prints the steps and
`./scripts/release.sh --local` makes an ad-hoc signed package you can inspect without any credentials. A build
without `SPARKLE_FEED_URL` and `SPARKLE_PUBLIC_ED_KEY` (every development build) never starts the updater or
contacts the network.

Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` for each release.

## Status

Version 0.1.0: the feature set above is implemented and covered by unit and UI tests. Not yet included: a desktop
widget, a Focus filter, a multi-day view beyond seven days and a Mac App Store build (the code keeps Sparkle behind a
`DIRECT_DISTRIBUTION` flag for that).

## License

MIT, see [LICENSE](LICENSE). The bundled open source packages (KeyboardShortcuts, Sparkle) keep their own
licenses, listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
