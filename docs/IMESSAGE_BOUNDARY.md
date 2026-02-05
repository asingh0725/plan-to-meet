# PlanToMeet iMessage Boundary

## Source of truth
- All scheduling logic, availability modeling, and slot generation live in TypeScript.
- The Supabase-backed web/app UI is the only place that creates and persists polls, availability blocks, and time slots.

## Swift responsibilities
- The iMessage extension hosts the web UI in a WKWebView.
- It passes users into `/create?source=imessage` and sends the resulting poll URL in an MSMessage.
- It must **not** generate slots, calculate availability, or store calendar data.

## Prohibited in Swift
- Re-implementing scheduling logic.
- Persisting availability or slots.
- Writing to Supabase directly (all writes go through the web/app UI).

## Allowed in Swift
- UI shell and message composition.
- Opening existing poll URLs.
- Reading the current WKWebView URL when sending a message.
