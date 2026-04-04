# App Store Submission Package

This folder contains the local material needed to finish the App Store Connect side of the first iOS submission for PlanToMeet.

Files:

- `product-page.md`: Product page metadata to paste into App Store Connect.
- `privacy.md`: Draft App Privacy answers based on the current codebase.
- `review-notes.md`: Review notes and the remaining human-entered fields.
- `screenshots.md`: Screenshot requirements and the recommended shot list.

Known manual steps that still require App Store Connect access:

1. Enter the metadata from `product-page.md`.
2. Complete the App Privacy questionnaire using `privacy.md`.
3. Upload iPhone, iPad, and iMessage screenshots described in `screenshots.md`.
4. Fill in App Review contact name, email, and phone number in App Store Connect.
5. Replace placeholder production values in `ios/PlanToMeet/Secrets.xcconfig` before the signed submission archive.
6. Upload the signed archive produced from Xcode Organizer.
