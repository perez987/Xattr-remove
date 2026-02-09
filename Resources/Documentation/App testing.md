# Testing Guide for Xattr-remove

This guide provides comprehensive testing scenarios to validate the application.

## Changes Implemented

1. **Differentiated Alert Messages**: The app  shows different messages based on:

2. 
   - Files where quarantine attribute was removed
   - Files where quarantine attribute was not present
   - Mixed results (some removed, some already clean)

3. **Auto-Quit Functionality**: The app automatically quits 3 seconds after displaying a success alert

4. **Updated Error Handling**: Errors do not trigger auto-quit (requires user acknowledgment)

## Testing Scenarios

### Scenario 1: Single File with Quarantine Attribute

Download a file from the internet to ensure it has the quarantine attribute

**Test Case: Drop on App Window, Finder icon or Dock icon**

1. Drag the downloaded file onto the app window
2. **Expected Result:** 
   - Alert shows: "Successfully removed quarantine attribute from file."
   - Alert disappears and app quits after 3 seconds

### Scenario 2: Multiple Files with Quarantine Attribute

Download multiple files from the internet

**Test:**

1. Select all downloaded files and drag them onto the app (window/icon/dock)
2. **Expected Result:** 
   - Alert shows: "Successfully removed quarantine attribute from N files." (where N is the number of files)
   - Alert disappears and app quits after 3 seconds

### Scenario 3: Single File without Quarantine Attribute

Create a new file locally (e.g., `touch test.txt`)

**Test:**

1. Drag the locally created file onto the app
2. **Expected Result:** 
   - Alert shows: "Successfully processed 1 file (quarantine attribute was not present)."
   - Alert disappears and app quits after 3 seconds

### Scenario 4: Multiple Files without Quarantine Attribute

Create multiple files locally (e.g., `touch test1.txt test2.txt test3.txt`)

**Test:**

1. Select all locally created files and drag them onto the app
2. **Expected Result:** 
   - Alert shows: "Successfully processed N files (quarantine attribute was not present)." (where N is the number of files)
   - Alert disappears and app quits after 3 seconds

### Scenario 5: Mixed Files (Some with, Some without Quarantine Attribute)

Prepare:
   - files downloaded from the internet (with quarantine attribute)
   - files created locally (without quarantine attribute)

**Test:**

1. Select all mixed files and drag them onto the app
2. **Expected Result:** 
   - Alert shows: "Successfully processed N files (X removed, Y already cleaned)."
     - N = total number of files
     - X = number of files where attribute was removed
     - Y = number of files where attribute was not present
   - Alert disappears and app quits after 3 seconds

### Scenario 6: Error Handling (Protected File)

1. Try to drop a file from a system-protected location (if possible)
2. Or test with a file in a location without write permissions

**Test:**

1. Drag the protected file onto the app
2. **Expected Result:** 
   - Alert shows: "Failed to remove quarantine attribute. The file may be in a protected location or require administrator privileges."
   - Alert stays visible and does NOT auto-quit
   - User must click "OK" to dismiss the alert
   - App remains open after dismissing the alert

### Scenario 7: Multiple Files with Errors

Prepare a mix of:
   - Normal files (that should process successfully)
   - Protected files (that should fail)

**Test:**

1. Drag all files onto the app
2. **Expected Result:** 
   - Alert shows: "Failed to remove quarantine attribute from N file(s). Some files may be in protected locations or require administrator privileges."
   - Alert does NOT auto-quit
   - User must click "OK" to dismiss
   - App remains open after dismissing the alert

## Verification Checklist

After completing all scenarios, verify:

- [ ] All three drop methods work (window, Finder icon, Dock icon)
- [ ] Alert messages correctly reflect the processing result
- [ ] Single vs. multiple file messages are grammatically correct
- [ ] Auto-quit occurs exactly 3 seconds after success alert appears
- [ ] Auto-quit does NOT occur for error alerts
- [ ] Error alerts require user interaction to dismiss
- [ ] App remains responsive throughout all operations
- [ ] Console logs show appropriate information for debugging

## Console Output

When running from Xcode, you should see console logs like:

```
Processing N file(s)
Processing complete: X removed, Y not found, Z failed
```

Where:
- N = total files processed
- X = files where quarantine attribute was removed
- Y = files where attribute was not present
- Z = files that failed to process

## Notes

- The quarantine attribute is typically added by macOS to files downloaded from the internet
- Local files (created with `touch`, TextEdit, etc.) typically don't have this attribute
- You can manually add the quarantine attribute for testing using:
  ```bash
  xattr -w com.apple.quarantine "0000;00000000;Safari;" test.txt
  ```
- You can check if a file has the quarantine attribute using:
  ```bash
  xattr -l test.txt
  ```
- To remove it manually for re-testing:
  ```bash
  xattr -d com.apple.quarantine test.txt
  ```
