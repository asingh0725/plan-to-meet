# Monetization Strategy

Last updated: April 4, 2026

## Thesis

PlanToMeet should stay free to discover, free to vote, and free to share.

The paid surface should be the organizer's upgrade layer:

- premium event tools
- sold as event passes
- purchased with in-app purchases in the iPhone app

That fits the product's actual growth loop:

- one person organizes
- everyone else responds
- the link, App Clip, and iMessage flow spread the product

Charging respondents would kill distribution. Charging organizers only when they want better control preserves the free loop and creates revenue.

## Why Not Subscriptions

A subscription is too much commitment for a lightweight consumer scheduling app.

The current market still anchors users around free entry and light organizer monetization:

- [Calendly pricing](https://calendly.com/pricing)
- [Doodle pricing](https://help.doodle.com/en/articles/9457366-how-much-does-doodle-cost)
- [Rallly pricing](https://rallly.co/pricing)
- [Partiful pricing](https://help.partiful.com/hc/en-us/articles/27354376389403-Does-Partiful-cost-money)

Inference:

- users expect to try scheduling products for free
- organizer-side payment is normal
- a one-off event unlock is easier to understand than a monthly plan for casual use

## Recommended Model

Launch model:

- free app download
- free voting forever
- free basic poll creation
- paid premium event tools via event passes

Recommended pack structure:

- `1 Event Pass`
- `5 Event Passes`
- `20 Event Passes`

The exact prices should be set in App Store Connect, but the product unit should stay event-based, not "100 polls."

## What An Event Pass Unlocks

A premium event can include:

- organizer note
- response deadline
- premium badge on the poll
- schedule-again flow for that event pattern

This is a better launch package than generic quotas because it maps to an actual organizer job:

`I am hosting this event and want better control.`

## Product Rules

- never monetize voting
- never add ads
- keep App Clip access free
- keep web poll viewing free
- charge for organizer leverage, not participation
- premium should feel like a better hosted event, not a restricted basic poll

## Implementation Rules

- purchases happen in the main iPhone app with StoreKit
- the Messages extension stays focused on lightweight poll creation and sharing
- premium fields must render cleanly on the web and in iOS
- free poll creation must continue to work without any purchase setup

## Launch Economics

The goal is not to maximize price on day one. The goal is to maximize organizer conversion without killing trust.

That means:

- a small premium event unlock should feel impulsive
- multi-pack pricing should reward repeat organizers
- the pass balance should be visible and simple

The right metric is not "ARPU from everyone." It is:

`What percent of repeat organizers buy passes after seeing the premium tools once?`

## App Store Constraint

Because event passes are digital unlocks used inside the app, they should be sold with in-app purchase under Apple's current rules:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Offering, completing, and restoring in-app purchases](https://developer.apple.com/documentation/storekit/offering-completing-and-restoring-in-app-purchases)

## Near-Term Roadmap

Phase 1:

- ship event pass balance
- ship premium poll creation
- ship organizer note and response deadline
- gate schedule again behind premium events

Phase 2:

- reminder nudges
- recurring templates
- export
- organizer branding controls

Phase 3:

- team packs
- analytics
- organizer memory and reusable templates
