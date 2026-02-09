### Updating the Xcode Service after building new code

When you build and run a new version from Xcode, macOS may continue using the cached version of the service. To force macOS to use the updated service:

- Quit the app completely if it's running
- Clear the services cache by logging out and back in, or by running:

   ```bash
   /System/Library/CoreServices/pbs -flush
   ```
   Or, if that doesn't work:
   
   ```bash
   /System/Library/CoreServices/pbs -update
   ```   
- Build and run the app again from Xcode
- The service should now use the new version
- The Xcode service is not stored as a separate file. It's defined in the app's `Info.plist` and registered with macOS when the app runs. The service cache is stored by macOS at

```
~/Library/Caches/com.apple.ServicesMenu.Services.plist
~/Library/Caches/com.apple.nsservicescache.plist
```