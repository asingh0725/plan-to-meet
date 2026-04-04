# Monetization Strategy

Last updated: March 30, 2026

## Thesis

PlanToMeet should monetize the poll creator, not the participant.

That is the model that fits the current product:

- one person creates the poll
- many people respond for free
- viral distribution happens through iMessage links, the App Clip, and the web

If we charge voters, we kill the growth loop. If we keep voting free and charge organizers for speed, control, retention, and automation, we preserve distribution and create recurring revenue.

## Positioning

PlanToMeet is the fastest way for iPhone-heavy groups to agree on a time.

Core differentiators:

- native iMessage flow
- App Clip voting with no install friction
- no account required for respondents
- consumer-grade UX instead of enterprise scheduling software

The product should be positioned closer to `Doodle for iMessage groups` than `Calendly for sales teams`.

## What The Market Shows

Current pricing signals from public sources:

- Calendly sells a free plan, then paid organizer tiers at roughly `$10/seat/month` and `$16/seat/month`, with enterprise above that.
- Doodle sells a free entry point, then paid organizer plans at roughly `$14.95/month` individual or lower annual effective pricing, plus team plans.
- Rallly uses a free plan with poll deletion/retention pressure and a low-cost annual pro tier.
- Partiful keeps the core event product free and monetizes advanced flows like ticketing.

Sources:

- [Calendly pricing](https://calendly.com/pricing)
- [Doodle pricing](https://help.doodle.com/en/articles/9457366-how-much-does-doodle-cost)
- [Rallly pricing](https://rallly.co/pricing)
- [Partiful pricing](https://help.partiful.com/hc/en-us/articles/27354376389403-Does-Partiful-cost-money)

Inference:

- Free entry is table stakes.
- Charging the organizer is normal.
- Low-friction consumer scheduling products can support a light pro tier well before they support enterprise sales.

## Recommended Business Model

Phase 1:
`Freemium creator subscription`

Free:

- create basic polls
- unlimited respondents
- iMessage sharing
- App Clip voting
- finalize best time
- add to calendar
- standard retention window

Plus:
`$4.99/month or $39.99/year`

- unlimited active polls
- recurring poll templates and schedule-again shortcuts
- automated reminder nudges
- response deadlines and close dates
- longer poll history and retention
- advanced finalize tools and tie-break suggestions
- custom branding / hide PlanToMeet branding on shared poll pages
- CSV export / organizer reporting

Team:
`$14.99/organizer/month or $119/year`

- everything in Plus
- shared team workspace
- shared poll templates
- multiple organizers
- admin controls
- brand settings
- analytics
- priority support

## Why This Model Fits The Current Codebase

The current product already has the right free surface area:

- poll creation
- repeated organizer usage
- recurring polls
- reactions
- push notifications
- iCloud-backed organizer identity

That means the easiest paid expansion is to gate organizer-only convenience features rather than invent a new product line.

Best first paywall candidates:

1. unlimited active polls
2. automatic reminder nudges
3. extended retention / archive history
4. recurring templates and saved presets
5. custom branding on poll pages and messages
6. analytics / export

Do not gate:

- opening a poll
- voting
- App Clip access
- finalized event details

## Target Customers

Primary:

- friend-group organizers
- parents coordinating playdates, parties, carpools, and school events
- student org leaders
- sports team captains
- church/community group organizers

Secondary:

- small teams that live in iMessage and do not want enterprise calendar routing software
- recruiters or managers coordinating interview panels informally

The first paid cohort is not “everyone.” It is the person in every group who always ends up coordinating.

## Pricing Logic

Plus should be cheap enough to be an impulse purchase and expensive enough to matter.

Recommended launch pricing:

- monthly: `$4.99`
- annual: `$39.99`

Why:

- low enough for consumer group organizers
- far below Doodle and Calendly, which target more formal scheduling use cases
- high enough that 1,000 paying annual users is meaningful revenue

Illustrative revenue:

- 250 annual subscribers at `$39.99` = about `$10k/year` gross
- 1,000 annual subscribers at `$39.99` = about `$40k/year` gross
- 2,500 annual subscribers at `$39.99` = about `$100k/year` gross

That is the passive-income path: a small but durable organizer subscription base.

## Conversion Strategy

Best paywall triggers:

1. when a creator tries to make their fourth active poll
2. when they use `Schedule Again`
3. when they send reminders
4. when they want poll history older than the free retention window
5. after a poll gets strong engagement and the creator clearly sees value

Best message:

`Keep group scheduling free for everyone else. Upgrade as the organizer for unlimited polls, reminders, and history.`

## Distribution Strategy

Acquisition should compound through three channels:

1. Product-led virality
- every poll link is a growth asset
- the App Clip is the wedge
- the respondent experience must stay frictionless

2. App Store / SEO capture
- rank for terms like `when2meet`, `group scheduling`, `availability poll`, `doodle alternative`, `iMessage scheduling`
- expand landing pages and comparison content over time

3. Niche organizer loops
- parents
- school groups
- sports teams
- student clubs
- event hosts

## 90-Day Execution Plan

1. Ship subscriptions with one clear paid tier: Plus.
2. Add feature gating only to organizer-side premium actions.
3. Add a pricing screen and upgrade prompts in iOS.
4. Track conversion events:
- poll created
- poll shared
- poll responded to
- poll finalized
- reminder sent
- paywall shown
- subscription started
- subscription renewed
5. Launch App Store listing with clear organizer messaging.
6. Publish comparison pages on the web:
- PlanToMeet vs Doodle
- PlanToMeet vs When2Meet
- PlanToMeet for parents
- PlanToMeet for teams

## Product Rules

- Never monetize the voting side.
- Never add ads to shared poll pages or the App Clip.
- Keep the free tier useful enough to spread.
- Charge for organizer leverage, not basic participation.

## Immediate Build Order

1. StoreKit 2 subscription infrastructure
2. premium entitlement checks in the iOS app
3. premium organizer features:
- active poll limits
- reminders
- longer retention
- templates / presets
4. pricing / paywall UI
5. analytics instrumentation

## Success Metrics

North star:

- paid organizer count

Supporting metrics:

- polls created per week
- poll responders per created poll
- finalize rate
- creator 30-day retention
- upgrade rate from creators to Plus
- annual-plan mix

## Bottom Line

The right business is:

- free for respondents
- subscription for organizers
- consumer-first pricing
- team/workspace expansion later

That is the cleanest path from today’s product to recurring passive revenue without breaking the growth loop that makes the app valuable.
