# myscan App Store Submission Pack

Last updated: 2026-06-01

## 1. Privacy Policy and GitHub Pages URL

Privacy policy file in repo:

- `docs/privacy-policy.md`

GitHub Pages publish steps:

1. Open GitHub repo: `oussamaelhajoui/myscan`
2. Go to `Settings` -> `Pages`
3. Under `Build and deployment`:
   - Source: `Deploy from a branch`
   - Branch: `main`
   - Folder: `/docs`
4. Save and wait for Pages deployment.

Expected privacy policy URL:

- `https://oussamaelhajoui.github.io/myscan/privacy-policy`

If your Pages setup serves `.md` as a file path, use:

- `https://oussamaelhajoui.github.io/myscan/privacy-policy.md`

Use whichever URL opens correctly in browser and place it in App Store Connect under:

- `App Privacy` -> `Privacy Policy URL`

Contact email in policy:

- `oussama.elhajoui@gmail.com`

## 2. Fix "Unable to Add for Review" (Required Fields)

Complete all of these in App Store Connect:

1. Choose a build
2. Complete Contact Information section
3. Select primary category
4. Set Content Rights Information
5. Enter Privacy Policy URL
6. Complete age ratings questionnaire
7. App Privacy section must be completed by Admin
8. Choose a price tier
9. Add English (U.S.) description
10. Add English (U.S.) keywords
11. Add English (U.S.) support URL

## 3. Suggested Values You Can Use

Support URL:

- You can use your GitHub repository URL:
  - `https://github.com/oussamaelhajoui/myscan`

Keywords suggestion:

- `network scanner,port scanner,lan,diagnostics,ip scan`

Primary category suggestion:

- `Utilities`

Content rights:

- Select that you own or have rights to all content.

Price tier:

- `Free` (or your chosen tier)

## 4. Build Upload (Where to Find It)

### In Xcode Organizer

1. Xcode -> `Window` -> `Organizer`
2. `Archives` tab
3. Select latest `myscan` archive
4. Click `Distribute App` -> `App Store Connect` -> `Upload`

### On disk (archive files)

Default archive path:

- `~/Library/Developer/Xcode/Archives/<date>/myscan <time>.xcarchive`

You can open this folder in Finder:

1. Finder -> `Go` -> `Go to Folder...`
2. Paste: `~/Library/Developer/Xcode/Archives`

### CI/CLI build path used in this project

Build output path used during validation:

- `/private/tmp/myscan-derived/Build/Products/Release-iphoneos/myscan.app`

Note: For App Store submission, use an Xcode Archive upload from Organizer (signed with your Apple Developer team), not just the raw `.app`.

## 5. App Privacy (No Data Collected)

For App Store Connect `App Privacy`, set answers consistent with your app behavior:

- Data Not Collected: `Yes` (if this remains true)
- Tracking: `No`
- Selling/sharing: `No`

Keep this synchronized with:

- `myscan/PrivacyInfo.xcprivacy`
- `docs/privacy-policy.md`

## 6. Final Pre-Submission Check

1. Build is uploaded and processed in App Store Connect
2. Build is selected in the version page
3. Description, keywords, support URL are filled
4. Privacy Policy URL opens publicly in browser
5. Contact Information is complete
6. Category, Content Rights, Age Rating, Pricing are complete
7. App Privacy questionnaire is complete (Admin requirement)
8. Submit for review
