# Premium Launch Brief

Last updated: April 4, 2026

## Brand

Core promise:

`PlanToMeet keeps group scheduling easy for everyone else, and gives the organizer better tools when it matters.`

Naming:

- paid unit: `Event Pass`
- paid event state: `Premium Event`

Tone:

- consumer, not enterprise
- warm and useful, not productivity-jargon-heavy
- clear that voting stays free

Good message examples:

- `Keep voting free. Upgrade the event, not the group.`
- `Use an Event Pass when this plan needs deadlines, notes, and a faster rerun.`
- `Better tools for the organizer. Zero friction for everyone else.`

## Marketing

Primary audiences:

- parents organizing group plans
- friend-group hosts
- student leaders
- coaches and community organizers

Core message hierarchy:

1. fastest way to find a time in iMessage
2. no install needed for voters
3. premium tools are only for the organizer

Launch claims the product can honestly support now:

- `Create and share polls in iMessage`
- `Vote instantly with the App Clip or web link`
- `Use Event Passes for organizer notes, response deadlines, and premium scheduling tools`

App Store / landing-page language should avoid:

- calendar-routing language that sounds like B2B sales software
- hard subscription framing
- big claims about teams or analytics before those features ship

## Product

The first premium slice should feel complete on its own.

Included in v1:

- starter event-pass balance for activation
- StoreKit product plumbing in the iPhone app
- premium poll creation
- organizer note
- response deadline
- premium badge and rendering on shared poll pages
- premium-only schedule-again flow

Explicitly out of scope for this pass:

- backend-enforced paywalls
- reminder automation
- CSV export
- team workspaces
- web checkout

## Design Rules

- premium UI should explain value in plain language before asking for money
- pass balance should be visible where organizers make decisions
- premium controls should sit inside poll creation, not in a detached paywall only
- shared poll pages should show premium value without punishing respondents

## Success Criteria

- a free user can still create and share a basic poll in under a minute
- a repeat organizer can understand what an event pass does without reading docs
- premium polls look meaningfully better to participants
- the app is structurally ready for App Store Connect IAP setup
