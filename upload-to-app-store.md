1. Join Apple Developer Program
      - You need a paid Apple Developer account.
      - https://developer.apple.com/programs/

  2. Create the app in App Store Connect
      - Go to https://appstoreconnect.apple.com
      - My Apps → + → New App
      - Use your bundle ID: com.snowsites.myscan
      - Fill app name, SKU, platform, category, etc.

  3. Prepare the Xcode project
     In Xcode:
      - Open myscan.xcodeproj
      - Select the myscan target
      - Set your Apple Team under Signing & Capabilities
      - Confirm:
          - Version: 1.0
          - Build: increase each upload, e.g. 1, then 2, etc.
          - Bundle ID matches App Store Connect

      - Confirm the privacy manifest exists: myscan/PrivacyInfo.xcprivacy

  4. Archive the app
     In Xcode:
      - Select a real destination: Any iOS Device
      - Product → Archive
      - When Organizer opens, select the archive
      - Click Distribute App
      - Choose App Store Connect
      - Upload

     Apple’s official Xcode upload guide: https://help.apple.com/xcode/mac/current/en.lproj/dev442d7f2ca.html

  5. Wait for build processing
     In App Store Connect:
      - My Apps → your app → TestFlight or App Store tab
      - Wait until the uploaded build finishes processing.

  6. Fill App Store listing
     You need:
      - App description
      - Keywords
      - Support URL
      - Privacy Policy URL
      - Screenshots for required device sizes
      - Age rating
      - App privacy answers
      - Review notes explaining the network scanner behavior

     I already added a local checklist here:
     AppStoreChecklist.md

  7. Submit for review
      - Select the processed build
      - Complete all required metadata
      - Submit for App Review
