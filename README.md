# PlanToMeet

A mobile-first scheduling app that helps groups find a common time to meet. Inspired by When2Meet, optimized for sharing via iMessage/SMS/WhatsApp.

## Features

### Core Flow
1. **Create a Poll** - Set event title, duration, date range, and mark availability
2. **Share** - Copy link or share directly via any messaging app
3. **Respond** - Tap Yes/Maybe/No for each time slot
4. **Decide** - View ranked results, finalize the best time

### Key Features
- **No accounts required** - Anyone can respond via shared link
- **Day-specific availability** - Mark availability for each day independently (When2Meet-style)
- **Visual Grid Picker** - Tap cells on a calendar grid to mark when you're free
- **Calendar Integration** - Optionally sync with your device calendar to see busy times while selecting availability
- **Conflict Indicators** - Amber highlights show when selected times overlap with calendar events
- **Slot Preview** - See exactly what time options will be generated, grouped by date
- **Visual results** - See ranked options with Yes/Maybe/No counts
- **One-tap finalize** - Lock in the best time with a single tap
- **Dark mode design** - Apple-native aesthetic

## Availability Model

The app uses **day-specific availability** (not a global daily window):

- Users mark availability for specific days and times
- Each day is independent
- Gaps and non-contiguous blocks are allowed
- Example: Free on Mon 9-11am, Tue 1-4pm, but not Wed at all

This matches real-world scheduling behavior.

## Calendar Integration

The app optionally integrates with your device's calendar:

- **Toggle on** "Use my calendar" to see busy times in the grid picker
- **Busy cells** appear muted with a diagonal stripe pattern
- **Conflict cells** (selected + busy) appear in amber
- **Privacy-first**: Calendar data stays on your device and is only used to highlight conflicts
- Conflicts are carried through to the slot preview with an indicator

This helps users avoid scheduling over existing commitments while still allowing flexibility.

## App Structure

```
src/app/
├── (tabs)/
│   ├── _layout.tsx      # Tab configuration (hidden)
│   └── index.tsx        # Home screen - poll list
├── create.tsx           # Create new poll with availability picker
├── poll/[id].tsx        # Poll detail & response
├── settings.tsx         # User settings
└── _layout.tsx          # Root navigation

src/components/
├── AvailabilityGridPicker.tsx  # When2Meet-style grid picker
└── ...
```

## Data Model

```typescript
DayAvailabilityBlock {
  id: string
  date: string           // YYYY-MM-DD
  startHour: number      // 0-23
  startMinute: number    // 0-59
  endHour: number
  endMinute: number
}

Poll {
  id: string
  title: string
  durationMinutes: number
  dateRangeStart: string
  dateRangeEnd: string
  dayAvailability: DayAvailabilityBlock[]
  timeSlots: TimeSlot[]
  responses: Response[]
  status: 'open' | 'finalized'
  finalizedSlotId?: string
}
```

## Slot Generation Logic

Time slots are generated from day-specific availability:
- Each slot must fit fully inside a marked availability block
- Slots respect the selected duration
- Slots are associated with specific dates

Example:
- Jan 30: Marked 9–11 AM, Duration 1h → Slots: 9–10, 10–11
- Jan 31: Marked 1–4 PM, Duration 1h → Slots: 1–2, 2–3, 3–4
- Feb 1: No availability marked → No slots

## State Management

- **Zustand** with AsyncStorage persistence for local poll data
- **React Query** hooks wrapping Zustand for consistent async patterns
- All scheduling logic in `src/lib/poll-store.ts`
- Database hooks in `src/lib/use-database.ts`

The app uses a React Query wrapper around Zustand store, providing:
- Consistent loading/error states
- Automatic query invalidation on mutations
- Type-safe hooks for all operations

## Design System

- Dark theme with zinc color palette
- Blue primary accent (#3b82f6)
- Emerald for success/finalized states
- Amber for warnings/conflicts
- Haptic feedback on interactions
- Smooth animations via react-native-reanimated

## Phase 2: Deep Links & iMessage Integration

### URL Schemes

The app supports two URL formats for opening polls:

1. **Universal Links** (recommended): `https://plantomeet.app/poll/{pollId}`
2. **Custom Scheme**: `plantomeet://poll/{pollId}`

### Universal Links Setup (REQUIRED FOR PRODUCTION)

For universal links to work, you must host an `apple-app-site-association` file on your domain.

**Path**: `https://plantomeet.app/.well-known/apple-app-site-association`

**Content** (no `.json` extension, served with `application/json` content type):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.aviraj.plantomeet",
        "paths": ["/poll/*"]
      }
    ]
  },
  "webcredentials": {
    "apps": ["TEAM_ID.com.aviraj.plantomeet"]
  }
}
```

**Replace `TEAM_ID` with your Apple Developer Team ID** (found in your Apple Developer account).

**Server requirements**:
- File must be served over HTTPS
- Content-Type: `application/json`
- No redirects on the `.well-known` path
- File must be accessible without authentication

### iMessage Extension

The iMessage extension allows users to:
1. Create polls directly within iMessage
2. Share poll links as rich message bubbles
3. Tap existing poll messages to open them in the main app

**Bundle Identifiers**:
- Main app: `com.aviraj.plantomeet`
- iMessage extension: `com.aviraj.plantomeet.messageextension`

### Deep Link Behavior

| Scenario | Behavior |
|----------|----------|
| Valid poll ID, app installed | Opens poll detail screen |
| Valid poll ID, app not installed | Opens web fallback (plantomeet.app) |
| Invalid/missing poll ID | Shows "Poll not found" error screen |
| Malformed URL | Silently ignored (no crash) |
