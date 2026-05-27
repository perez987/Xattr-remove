# CLAUDE.md — Xattr-remove

## Project Overview

**Xattr-remove** is a lightweight macOS SwiftUI "droplet" app that removes the `com.apple.quarantine` extended attribute from files dragged onto its window. It is **not** sandboxed, to ensure reliable use of the `removexattr()` system call.

- **Language:** Swift 5 / SwiftUI
- **Minimum macOS:** 13.0 (Ventura)
- **Build tool:** Xcode (no command-line, only build path)

## Repository Layout

```
Xattr-remove-2/
├── CLAUDE.md                              # This file
├── README.md                              # User-facing English documentation
├── README-ES.md                           # User-facing Spanish documentation
├── Images/                                # Screenshots and app icons used in READMEs
├── DOCS/
│   ├── Project-structure.md               # Technical architecture docs
│   ├── Implementation-notes.md            # Design decisions and issue history
│   ├── App-testing.md                     # Manual test scenarios
│   └── Update-Xcode-service.md            # How to refresh the macOS Finder service cache
├── Xattr-remove.xcodeproj/                # Xcode project (open this to build)
└── Xattr-remove/                          # Main app source
    ├── Xattr_removeApp.swift              # @main entry point; sets up WindowGroup, menus, Sparkle
    ├── Info.plist                         # App configuration
    ├── Xattr_remove.entitlements          # Sandboxing DISABLED (required for removexattr)
    ├── Assets.xcassets/                   # App icons and accent color
    ├── Views/
    │   ├── ContentView.swift              # Drag-and-drop UI; delegates to FileProcessor
    │   └── CustomAlertView.swift          # Sheet-based alert (avoids icon shown by SwiftUI alerts)
    ├── Model/
    │   ├── XattrManager.swift             # removexattr() and codesign wrappers; returns result enums
    │   └── FileProcessor.swift            # ObservableObject; orchestrates processing + alerts
    └── Languages/
        ├── LanguageSelectorView.swift     # Language picker sheet (5 languages)
        ├── en.lproj/Localizable.strings
        ├── es.lproj/Localizable.strings
        ├── de.lproj/Localizable.strings
        ├── fr.lproj/Localizable.strings
        └── it.lproj/Localizable.strings
```

## Architecture

The app follows a three-layer separation of concerns:

| Layer | File | Responsibility |
|---|---|---|
| Core | `XattrManager.swift` | Calls `removexattr()` and `codesign`; returns result enums; detects binary architecture |
| Logic | `FileProcessor.swift` | Counts results, builds alert messages, schedules auto-quit |
| UI | `ContentView.swift` | SwiftUI drag-and-drop, re-sign checkbox, shows `CustomAlertView` as a sheet |

### Data flow

1. User drops files onto the window → `ContentView.handleDrop()`
2. For a single file, `XattrManager.architectureDescription()` runs to detect the binary architecture; this result is displayed in the window and passed to `FileProcessor`
3. URLs are collected on a serial `DispatchQueue`, then `FileProcessor.processFiles(_:shouldResign:architectureInfo:)` is called
4. Each file is processed in parallel on `DispatchQueue.global(qos: .userInitiated)`: quarantine attribute is removed, and if `shouldResign` is true and the file is an `.app` bundle, it is re-signed via `codesign`
5. Results are posted back to a serial coordination queue and counted
6. `group.notify` fires on the coordination queue → builds `AlertState`, dispatches to main thread
7. On **success**: `CustomAlertView` sheet appears; app quits after 5 seconds (`exit(0)`)
8. On **error**: sheet appears, no auto-quit (requires user acknowledgment)

### `QuarantineRemovalResult` enum

```swift
case success          // Attribute removed
case notFound         // ENOATTR – attribute was absent (treated as success)
case permissionDenied // EPERM / EACCES
case otherError(String)
```

### `ReSignResult` enum

```swift
case success          // Sparkle.framework and app bundle re-signed successfully
case failure(String)  // codesign failed; message contains the error output
```
### Architecture detection

```swift
private static let architectureBundleExtensions = Set(["app", "framework", "bundle"])
private static let architectureLibraryExtensions = Set(["dylib", "so"])
```

### Thread safety

All counter increments (`removedCount`, `notFoundCount`, `xattrFailedCount`, `reSignSuccessCount`, `reSignFailedCount`) run on the same **serial** queue. `group.notify` targets that same queue, so reads are guaranteed to happen after all writes.

## Building

1. Open `Xattr-remove.xcodeproj` in Xcode (14.0+)
2. Select the **Xattr-remove** scheme
3. **⌘B** to build, **⌘R** to run
4. No external setup needed

## Testing

There are **no automated tests**. All testing is manual. Key scenarios are documented in [`DOCS/App-testing.md`](DOCS/App-testing.md):

- Single / multiple files with the quarantine attribute → success + auto-quit
- Single / multiple files without the attribute → "not present" success + auto-quit
- Mixed batches → mixed success message + auto-quit
- Files in protected locations → error alert, no auto-quit
- Re-sign option enabled with an `.app` bundle → quarantine removed + Sparkle and app re-signed

**Useful shell commands for manual testing:**

```bash
# Add quarantine attribute to a test file
xattr -w com.apple.quarantine "0000;00000000;Safari;" test.txt

# Verify attribute is present
xattr -l test.txt

# Remove attribute manually (for re-testing)
xattr -d com.apple.quarantine test.txt
```

## Localization

All user-facing strings are in `Localizable.strings` files under `Languages/<code>.lproj/`. Supported locales: `en`, `es`, `de`, `fr`, `it`.

When adding a new UI string:
1. Add the key/value to **all five** `.strings` files
2. Reference it via `NSLocalizedString("key", comment: "...")`

Language selection is persisted in `UserDefaults` (`AppleLanguages` key). A restart is required to apply a new language.

## Key Design Decisions

- **No sandbox**: Removed (`com.apple.security.app-sandbox = false`) because the macOS sandbox blocks `removexattr()` even with appropriate entitlements.
- **Auto-quit on success**: Intentional droplet behaviour — 5 seconds after a success alert the app calls `exit(0)`. Error alerts do not trigger auto-quit.
- **`CustomAlertView` instead of SwiftUI `.alert`**: Avoids the app icon shown by SwiftUI alerts on Sonoma/Sequoia.
- **`AlertState` struct**: Groups all alert properties so that a single `objectWillChange` is emitted, preventing "Publishing changes from within view updates" warnings.
- **`XATTR_NOFOLLOW` flag**: Prevents following symbolic links during attribute removal.
- **Re-sign checkbox (non-persistent)**: The re-sign option uses `@State` (not `@AppStorage`) so it always starts unchecked on launch — users must explicitly opt in each session.
- **Re-sign order**: Sparkle.framework is re-signed before the app bundle; this order is required for a valid code signature.
- **Architecture detection**: When a single file is dropped, `XattrManager.architectureDescription()` runs `lipo -archs` on the binary and displays the result (Intel, Silicon, or Universal) in the window and the success alert.

## Console Logs

The app writes its operational logs directly with `print()` from:

- `ContentView` (drag-and-drop loading errors)
- `XattrManager` (per-file xattr and re-sign results)
- `FileProcessor` (batch start/completion summary)

Reentrant drag IPC messages (e.g., `kDragIPCCompleted`) are macOS system messages and cannot be suppressed.
