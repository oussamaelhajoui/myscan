# App Store Readiness

## Current App Details

- App name: `myscan`
- Bundle identifier: `com.snowsites.myscan`
- Version: `1.0`
- Build: `1`
- Team ID: `H94LRLL489`
- Deployment target: iOS `26.5`

## Required Before Submission

- Confirm final App Store display name, subtitle, category, age rating, support URL, marketing URL, and privacy policy URL in App Store Connect.
- Confirm local-network scanning language in review notes. The app scans user-provided or detected local subnet hosts and ports.
- Confirm `NSLocalNetworkUsageDescription` copy is acceptable for App Review.
- Create screenshots for required iPhone and iPad sizes.
- Verify signing, capabilities, and provisioning in Xcode with the production Apple Developer account.
- Run `xcodebuild test` on a real available simulator before archive.
- Run a signed Release archive from Xcode Organizer and validate/upload to App Store Connect.

## Test Coverage Added

- Unit tests for cancellation, scanner open/closed result callbacks, configuration defaults, and app tab state.
- UI tests for launch, tab navigation, scan controls, live output/found hosts visibility, and settings controls.
