# Remove-quarantine: Finder service in a minimal app

*[Versión en español](README-ES.md)*

A minimal macOS app with no window and no Dock icon. Its only purpose is to provide the **Remove quarantine** service in the Finder context menu. Because the service is declared by an application (like Terminal's "New Terminal at Folder"), it appears at the **top level** of the context menu, not inside *Quick Actions*.

## What it does

- For each selected item (file, folder, `.app`, `.dmg`, `.pkg`) it removes **only** the `com.apple.quarantine` attribute, including inside folders and bundles. It is equivalent to `xattr -dr com.apple.quarantine`.
- It uses `removexattr()` with `XATTR_NOFOLLOW`, so it never follows symbolic links.
- It shows no messages. If the attribute is not present, it does nothing.
- macOS launches it in the background when the service is used, and it quits by itself 2 seconds later.
- It is not sandboxed, because the sandbox blocks `removexattr()`.
- The service title is localized: **Remove quarantine** (English, default) and **Eliminar cuarentena** (Spanish).

## Requirements

- macOS 13 or later.
- Xcode or the Command Line Tools (for `swiftc`, `lipo` and `codesign`).

## Installation

```bash
cd Finder-Service-App
./install.sh
```

The script:

1. Builds a universal app (Apple Silicon and Intel) in `build/`.
2. Copies it to `~/Applications/Remove-quarantine.app`.
3. Registers it with LaunchServices and opens it once so macOS reads the service. It quits by itself after 10 seconds.
4. Refreshes the services cache and relaunches the Finder.

Then make sure **Remove quarantine** is enabled in *System Settings → Keyboard → Keyboard Shortcuts → Services → Files and Folders*.

## Signing and notarization for other users

With an ad hoc signature the app works on your own Mac. On another Mac, Gatekeeper blocks it the first time and the user has to allow it in *System Settings → Privacy & Security*.

To avoid that, the app is already signed with a **Developer ID Application** certificate and notarized with Apple, so there shouldn't be any issues with Gatekeeper.

### Sign with your own certificate

If you want to generate the signed app using your own Apple Developer ID, here are the instructions:

**1. Notarization credentials (once).** You need an app-specific password, created at appleid.apple.com, and your Team ID.

Run (you only need to do it once):

```bash
xcrun notarytool store-credentials "notary-profile" --apple-id "you@example.com" --team-id "TEAMID"
```

It asks for the app-specific password.

**2. Build and sign.** `build.sh` looks for the first *Developer ID Application* identity in the keychain and signs with the hardened runtime and a secure timestamp. If it finds none, it signs ad hoc:

```bash
./build.sh
# or
sh build.sh
```

To choose the identity yourself:

```bash
SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./build.sh
```

**3. Notarize, staple the ticket and package:**

```bash
./notarize.sh
# or
sh notarize.sh
```

The result is `build/Remove-quarantine.zip`, ready to distribute.

**What the other user does:**

1. Unzips the file and moves `Remove-quarantine.app` to `/Applications` or `~/Applications`.
2. Opens it once. No Gatekeeper warning appears; the app quits by itself after 10 seconds and the service stays registered.
3. Makes sure **Remove quarantine** is enabled in *System Settings → Keyboard → Keyboard Shortcuts → Services → Files and Folders*.

## Rebuilding after code changes

```bash
./build.sh && ./install.sh
```

## Uninstalling

```bash
./uninstall.sh
```

## Files

| File | Purpose |
|---|---|
| `Sources/main.swift` | Service provider (`removeQuarantine:userData:error:`) and auto-quit |
| `Info.plist` | `LSUIElement` (no Dock icon), icon, localizations and `NSServices` declaration |
| `Resources/<lang>.lproj/ServicesMenu.strings` | Localized service title (`en`, `es`) |
| `AppIcon.png` | 1024×1024 icon; `build.sh` turns it into `AppIcon.icns` |
| `build.sh` | Build with `swiftc`, icon, localizations and signing (Developer ID or ad hoc) |
| `notarize.sh` | Notarization, ticket stapling and distribution zip |
| `install.sh` / `uninstall.sh` | Install and register the service, and remove it |

## Adding a language

Create `Resources/<code>.lproj/ServicesMenu.strings` with the translated title, add the code to `CFBundleLocalizations` in `Info.plist`, and rebuild:

```
"Remove quarantine" = "<translated title>";
```
