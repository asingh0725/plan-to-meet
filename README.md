# PlanToMeet

A mobile-first scheduling app that helps groups find a common time to meet. Create polls in iMessage, share with friends, and find the perfect time.

## Project Structure

```
TimeTogether/
├── ios/                    # Native iOS app (Swift/SwiftUI)
│   ├── PlanToMeet/         # Main iOS app
│   ├── PlanToMeetMessages/ # iMessage extension
│   ├── PlanToMeetClip/     # App Clip for instant voting
│   └── Shared/             # Shared code between targets
├── web/                    # Next.js web app
│   ├── src/app/            # Pages and routes
│   ├── src/components/     # React components
│   └── src/lib/            # Utilities and API
└── supabase/               # Database schema
```

## iOS Targets

| Target | Type | Bundle ID | Description |
|--------|------|-----------|-------------|
| PlanToMeet | App | `com.aviraj.plantomeet` | Main app for viewing polls and settings |
| PlanToMeetMessages | iMessage Extension | `com.aviraj.plantomeet.PlanToMeetMessages` | Create and vote on polls in iMessage |
| PlanToMeetClip | App Clip | `com.aviraj.plantomeet.Clip` | Instant voting when tapping poll links |

## Features

### Core Flow
1. **Create a Poll** - Set event title, duration, date range, and mark availability
2. **Share** - Send directly via iMessage or share link
3. **Respond** - Tap Yes/Maybe/No for each time slot
4. **Finalize** - Lock in the best time and add to calendar

### Key Features
- **Native iMessage Integration** - Create and share polls without leaving Messages
- **App Clip** - Instant native voting experience without downloading the app
- **No accounts required** - Anyone can respond via shared link
- **Visual Grid Picker** - Tap cells on a calendar grid to mark availability
- **Calendar Integration** - See busy times while selecting availability
- **Real-time Updates** - See votes as they come in via Supabase Realtime (WebSocket)
- **Push Notifications** - Get notified when your poll gets responses or is finalized
- **One-tap finalize** - Creator locks in the best time
- **Add to Calendar** - Everyone can add the finalized event
- **Reactions** - Leave an emoji reaction and comment on finalized polls
- **Schedule Again** - Clone a finalized poll with new dates for recurring events
- **iCloud Sync** - Session ID and display name sync across your devices

## iOS App

### Requirements
- iOS 16.0+
- Xcode 15+

### Setup
1. Open `ios/PlanToMeet.xcodeproj` in Xcode
2. Copy `ios/Shared/Secrets.xcconfig.example` to `ios/Shared/Secrets.xcconfig`
3. Add your credentials to `Secrets.xcconfig`:
   ```
   SUPABASE_URL = https://your-project.supabase.co
   SUPABASE_ANON_KEY = your-anon-key
   SENTRY_DSN = https://your-dsn@sentry.io/project-id   # optional
   SENTRY_ENVIRONMENT = development
   ```
4. Add required Xcode capabilities (Signing & Capabilities tab for PlanToMeet target):
   - **Push Notifications** — enables APNs
   - **Background Modes → Remote notifications** — wake on push
   - **iCloud → Key-value storage** — cross-device session sync
5. Add the Sentry Swift package (optional — crash reporting):
   File → Add Package Dependencies → `https://github.com/getsentry/sentry-cocoa`
   Add to the **PlanToMeet** target only.
6. Build and run

### Targets
- **PlanToMeet** - Main iOS app for viewing polls and settings
- **PlanToMeetMessages** - iMessage extension for creating/voting on polls
- **PlanToMeetClip** - App Clip for instant voting via poll links

## Web App

### Requirements
- Node.js 18+

### Setup
```bash
cd web
npm install
cp .env.example .env.local
# Edit .env.local with your Supabase credentials
npm run dev
```

### Features
- Server-side rendering for fast loads and OG tags
- PWA support - installable on mobile devices
- Real-time poll updates
- Calendar file download (.ics)

## Database (Supabase)

### Tables
- `polls` - Poll metadata (title, duration, status, parent_poll_id)
- `time_slots` - Available time options
- `responses` - User votes (yes/maybe/no)
- `participants` - Poll participants with display names
- `availability_blocks` - Creator's availability ranges
- `push_tokens` - APNs device tokens for push notifications
- `reactions` - Emoji reactions and comments on finalized polls

### Schema Setup

Run the consolidated migration in the Supabase SQL editor:

```bash
# In Supabase Dashboard → SQL Editor:
# 1. Run supabase/setup.sql  (creates push_tokens, reactions, adds parent_poll_id)
# 2. Set database config vars for pg_net triggers:
ALTER DATABASE postgres SET app.supabase_url = 'https://<ref>.supabase.co';
ALTER DATABASE postgres SET app.service_role_key = '<your-service-role-key>';
# 3. Enable pg_net extension: Project Settings → Database → Extensions → pg_net
# 4. Run supabase/triggers.sql  (auto-fires push notifications on DB events)
```

## Universal Links & App Clip

Polls are accessible at `https://plantomeet.app/poll/{pollId}`

- **iOS with app installed** → Opens main app
- **iOS without app** → App Clip slides up for instant voting
- **Other platforms** → Opens web app

### App Clip

The App Clip provides a native voting experience for iOS users who don't have the full app installed. When a user taps a poll link, the App Clip slides up from the bottom of the screen, allowing them to:

- View poll details and time slots
- Vote on times (Yes/Maybe/No)
- Add finalized events to calendar
- Download the full app

**Requirements:**
- Apple Developer Program membership (for Associated Domains capability)
- App Clip configured in App Store Connect

### Apple App Site Association

The AASA file is located at `web/public/.well-known/apple-app-site-association`:

```json
{
  "appclips": {
    "apps": ["3QY3LY2U66.com.aviraj.plantomeet.Clip"]
  },
  "applinks": {
    "details": [
      {
        "appIDs": [
          "3QY3LY2U66.com.aviraj.plantomeet",
          "3QY3LY2U66.com.aviraj.plantomeet.Clip"
        ],
        "components": [
          { "/": "/poll/*", "comment": "Poll pages" }
        ]
      }
    ]
  }
}
```

This file must be served at `https://plantomeet.app/.well-known/apple-app-site-association` with `Content-Type: application/json`.

## Design System

- Dark theme with zinc color palette
- Blue primary accent (#3b82f6)
- Green for success/finalized states
- Orange for "maybe" responses
- Red for "no" responses

## Development

### iOS Development
```bash
cd ios
open PlanToMeet.xcodeproj
```

### Web Development
```bash
cd web
npm run dev
```

### Environment Variables

**iOS** (`ios/Shared/Secrets.xcconfig`):
```
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_ANON_KEY = your-anon-key
SENTRY_DSN = https://your-dsn@sentry.io/project-id
SENTRY_ENVIRONMENT = development
```

**Web** (`web/.env.local`):
```
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

**Supabase Edge Function** (`supabase secrets set ...`):
```
APNS_KEY_P8=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----
APNS_KEY_ID=XXXXXXXXXX          # 10-char key ID from Apple Developer portal
APNS_TEAM_ID=XXXXXXXXXX         # 10-char team ID (Account → Membership)
APNS_BUNDLE_ID=com.aviraj.plantomeet
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
```

See `supabase/functions/send-push-notification/.env.example` for full details.

## Deployment

### Web (Vercel)
1. Connect repo to Vercel
2. Set root directory to `web`
3. Add environment variables
4. Deploy

### iOS (App Store)
1. Archive in Xcode (`Product → Archive`)
2. Upload to App Store Connect
3. Submit for review

### Push Notifications (Supabase Edge Function)
```bash
# 1. Set secrets
supabase secrets set \
  APNS_KEY_P8="$(cat /path/to/AuthKey_XXXXXXXXXX.p8)" \
  APNS_KEY_ID=XXXXXXXXXX \
  APNS_TEAM_ID=XXXXXXXXXX \
  APNS_BUNDLE_ID=com.aviraj.plantomeet \
  SUPABASE_URL=https://your-project.supabase.co \
  SUPABASE_SERVICE_ROLE_KEY=eyJ...

# 2. Deploy the function
supabase functions deploy send-push-notification

# 3. In Supabase SQL Editor — enable pg_net and install triggers
#    (after running setup.sql and setting app.supabase_url / app.service_role_key)
```

The DB triggers in `supabase/triggers.sql` automatically fire the Edge Function when:
- A new response is inserted (notifies poll creator)
- A poll is finalized (notifies all participants)

## License

MIT
