# PWA Screenshots

These screenshots are referenced in `/public/manifest.json` for the PWA install prompt on Chrome/Android.

## Required Files

| Filename | Dimensions | Content |
|---|---|---|
| `poll-voting.png` | 390×844px | Poll detail page showing time slots with Yes/Maybe/No vote buttons |
| `poll-results.png` | 390×844px | Finalized poll showing the winning time slot |
| `create-poll.png` | 390×844px | `/create` page with the poll creation form |

## How to Capture

1. Open Chrome DevTools → Toggle device toolbar → Set device to "iPhone 12 Pro" (390×844)
2. Navigate to each page on `plantomeet.app`
3. Take a screenshot (or use DevTools → Capture screenshot)
4. Save at the correct filename in this directory

## Notes

- Dark background (#05070C) should be visible
- No browser chrome (address bar) in the screenshots
- Compress PNGs before committing (target: <200KB each)
- Once App Store listing is live, update the `related_applications` URL in manifest.json
