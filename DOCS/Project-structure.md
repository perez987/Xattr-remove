# Xattr-remove

## Key Features

### 1. Drag-and-Drop Interface (ContentView.swift)

- Clean SwiftUI interface
- Visual feedback when files are dragged over (blue color)
- Accepts file drops onto the app window via `.onDrop()` modifier
- Background processing to avoid UI blocking
- Auto-quit after 3 seconds following successful processing

### 2. Quarantine Attribute Removal (XattrManager.swift)

- Uses `removexattr()` system call
- Handles three cases:
  - Success: Attribute removed
  - ENOATTR: Attribute doesn't exist (not an error)
  - Other errors: Logged but handled gracefully
- Proper logging with os.Logger

### 3. Window-Only Operation

- SwiftUI App structure with lightweight AppDelegate (via `NSApplicationDelegateAdaptor`) to disable window state restoration
- Files must be dropped onto the app window (not Finder or Dock icons)
- App automatically quits 3 seconds after successful processing


## Building and Running

1. Open `Xattr-remove.xcodeproj` in Xcode
2. Build (⌘B) and Run (⌘R)
3. Drop files onto the app window

## Requirements

- macOS 13.0 or later
- Xcode 14.0 or later (for building)

## Technical Details

### API Usage

- **removexattr()**: Removes extended attributes from files
- **SwiftUI**: Modern declarative UI framework
- **os.Logger**: Structured logging
- **DispatchQueue**: Background processing

### Error Handling

The app provides user-friendly feedback through differentiated alerts:

- **Success (files with quarantine attribute)**: Shows specific message when quarantine attribute is successfully removed
  - Single file: "Successfully removed quarantine attribute from file."
  - Multiple files: "Successfully removed quarantine attribute from N files."
- **Success (files without quarantine attribute)**: Shows specific message when attribute was not present
  - Single file: "Successfully processed 1 file (quarantine attribute was not present)."
  - Multiple files: "Successfully processed N files (quarantine attribute was not present)."
- **Mixed results**: Shows combined message with counts
  - "Successfully processed N files (X removed, Y already cleaned)."
- **Error**: Alerts users when files cannot be modified due to permission restrictions
  - Single file: "Failed to remove quarantine attribute. The file may be in a protected location or require administrator privileges."
  - Multiple files: "Failed to remove quarantine attribute from N file(s). Some files may be in protected locations or require administrator privileges."

After displaying a success alert, the app automatically quits after 3 seconds. Error alerts do not trigger auto-quit as they require user attention.

## Implementation

The app uses the `removexattr` system call to remove the `com.apple.quarantine` extended attribute from files. This attribute is automatically added by macOS to files downloaded from the Internet and triggers the "This file was downloaded from the Internet" warning dialog.

**Core Logic** (`XattrManager.swift`)

- Uses `removexattr()` system call with `XATTR_NOFOLLOW` flag to avoid following symbolic links
- Verifies file existence before attempting removal
- Returns structured result (success, notFound, permissionDenied, or otherError)
- Handles ENOATTR as success (attribute absent)
- Handles EPERM and EACCES (permission denied) gracefully with user feedback
- Structured logging via `os.Logger`

```swift
static func removeQuarantineAttribute(from url: URL) -> QuarantineRemovalResult {
    let path = url.path
    
    // First verify the file exists
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: path) else {
        logger.error("File does not exist at path: \(path)")
        return .otherError("File not found")
    }
    
    // Attempt to remove the attribute using C API
    // Use XATTR_NOFOLLOW to not follow symbolic links
    let result = removexattr(path, quarantineAttribute, XATTR_NOFOLLOW)
    
    if result == 0 {
        logger.info("Successfully removed quarantine attribute from: \(path)")
        return .success
    } else {
        let error = errno
        if error == ENOATTR {
            logger.debug("Quarantine attribute not found on: \(path)")
            return .notFound
        } else if error == EPERM || error == EACCES {
            logger.warning("Permission denied when removing quarantine attribute from \(path)")
            return .permissionDenied
        } else {
            let errorMsg = String(cString: strerror(error))
            logger.error("Error removing quarantine attribute from \(path): \(errorMsg)")
            return .otherError(errorMsg)
        }
    }
}
```

**UI** (`ContentView.swift`)

- SwiftUI drag-and-drop with `.onDrop(of: [.fileURL])`
- Background thread processing via `DispatchQueue.global(qos: .userInitiated)`
- Visual feedback on drag-over
- User alerts showing differentiated success/failure messages
- Batch processing with `DispatchGroup` for coordinated completion
- Auto-quit 3 seconds after successful processing

**File Processing** (`FileProcessor.swift`)

- Tracks three categories of results:
  - `removedCount`: Files where quarantine attribute was successfully removed
  - `notFoundCount`: Files where quarantine attribute was not present
  - `failedCount`: Files that could not be processed due to errors
- Displays context-appropriate alert messages based on result counts
- Schedules automatic app termination 3 seconds after success alert
- Errors do not trigger auto-quit (requires user acknowledgment)

**Configuration**

- `Info.plist`: Basic application configuration without document type support
- `Entitlements`: Sandbox **disabled** (`com.apple.security.app-sandbox` set to `false`) to allow full file system access for extended attribute removal
- Target: macOS 13.0+

## Console Messages

When running in Xcode, you may see the following console messages:

- **Permission denied warnings**: May occur for files in protected system locations. The app displays user-friendly alerts when this happens.
- **Reentrant drag IPC messages** (e.g., "kDragIPCCompleted"): System-level macOS drag-and-drop messages that cannot be suppressed by the application.

The `XATTR_NOFOLLOW` flag prevents the app from following symbolic links, which helps avoid permission issues.

## Security Note

This app runs without macOS sandboxing to ensure reliable extended attribute removal. While sandboxed apps provide additional security isolation, they face significant limitations when modifying file extended attributes (specifically, the macOS sandbox restricts system calls like `removexattr()` even with appropriate entitlements and security-scoped resource access) resulting in frequent "Operation not permitted" errors even with appropriate entitlements.

Since this app only performs a specific, well-defined operation (removing the quarantine attribute), and only operates on files explicitly provided by the user via drag-and-drop onto the app window, the security risk of running unsandboxed is minimal.

## File Structure

```
Xattr-remove/
├── README.md                          # User documentation
├── Resources/
│   ├── Project-structure.md           # Technical documentation
│   ├── AppIcon.icns                   # App icon
│   └── *.png                          # Screenshots and assets
├── .gitignore                         # Git ignore patterns
├── Xattr-remove.xcodeproj/
│   └── project.pbxproj                # Xcode project configuration
└── Xattr-remove/                      # Main application bundle
    ├── Xattr_removeApp.swift          # App entry point (@main)
    ├── Views/
    │   └── ContentView.swift          # Main UI with drag-and-drop
    ├── Model/
    │   ├── FileProcessor.swift        # Processing coordination and alerts
    │   └── XattrManager.swift         # Core xattr removal logic
    ├── Info.plist                     # App configuration (droplet support)
    ├── Xattr_remove.entitlements      # Security entitlements
    └── Assets.xcassets/               # App assets
```
