# App Privacy Draft

Source basis:

- Current iOS code in `ios/`
- Current privacy policy in `web/src/app/privacy/page.tsx`
- Current archive configuration as of March 30, 2026

Recommended top-level answers:

- Tracking: `No`
- Data linked to the user: `Yes`
- Data used for third-party advertising: `No`
- User Privacy Choices URL: `https://plantomeet.app/support`

Recommended disclosed data types:

1. `Name`
Purpose:
`App Functionality`
Why:
Users enter a display name that is stored locally and sent with poll participation.

2. `User ID`
Purpose:
`App Functionality`
Why:
The app creates a random session identifier and uses it to associate polls, votes, and reactions with the same participant across devices.

3. `Other User Content`
Purpose:
`App Functionality`
Why:
The app sends poll titles, availability selections, yes/maybe/no responses, emoji reactions, and optional text comments to the backend so participants can collaborate on a schedule.

4. `Device ID`
Purpose:
`App Functionality`
Why:
If push notifications are enabled, the app stores an APNs device token to deliver poll notifications.

Recommended not collected:

- Contacts
- Location
- Browsing history
- Search history
- Purchases
- Financial info
- Health and fitness
- Photos or videos
- Audio data
- Precise calendar contents

Important implementation note:

- Calendar access is used only to highlight conflicts and add finalized events. The current code keeps calendar event data on-device and does not upload it to Supabase.

Conditional disclosure:

- If production builds ship with `SENTRY_DSN` empty, do not disclose crash or performance diagnostics from Sentry because they are not collected.
- If production builds ship with Sentry enabled, disclose at least:
  - `Crash Data`
  - `Performance Data`

Conservative recommendation if Sentry is enabled:

- Purpose: `App Functionality`
- Tracking: `No`

Manual confirmation still required before submission:

1. Decide whether the production App Store build will enable Sentry.
2. If Sentry is enabled, confirm whether any user/session context is attached in production. If it is, mark diagnostics as linked to the user. If it is not, diagnostics may be disclosed as not linked.

Inference note:

- The `Device ID` recommendation is an inference from storing APNs tokens in `push_tokens`.
- The `Other User Content` recommendation is an inference from poll titles and optional reaction comments being user-authored content persisted to the backend.
