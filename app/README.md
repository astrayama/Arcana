# Arcana — iOS

A native SwiftUI tarot journal, built from the Claude Design wireframes
(`project/Wireframes.dc.html`, hi-fi turn 2). Cosmic-glass aesthetic, ledger-book
journal, 10-second card logging, and image/PDF spread export.

## Structure the app implements

| Wireframe | Screen | Source |
|---|---|---|
| 2a | Today home — floating daily card, spreads entry, quiet streak link | `Arcana/Features/Today/TodayView.swift` |
| 2b | Quick-log sheet (default logging path) | `Arcana/Features/Log/QuickLogSheet.swift` |
| 2c | Draw from the deck — tilt-drifting fan, hold-to-draw, 3D flip | `Arcana/Features/Log/DrawView.swift` |
| 2d | Journal — the ledger book (month pages, stats, filters, swipe) | `Arcana/Features/Journal/JournalView.swift` |
| 2e | Spread detail — stagger-fade cards, notes, insight, export | `Arcana/Features/Spreads/SpreadDetailView.swift` |
| 2f | Export — Post 1:1 / Story 9:16 / Journal PDF + share sheet | `Arcana/Features/Export/` |
| 2g | First entry — guided 3-step (shown once) | `Arcana/Features/Log/GuidedFirstEntryFlow.swift` |
| 2h | Onboarding — intro, Apple/email sign-in, reminder ask | `Arcana/Features/Onboarding/OnboardingFlow.swift` |
| 2i | Widgets — small/medium home + lock-screen circular | `ArcanaWidgets/` |
| — | Spreads home + builder (flow between 2a and 2e) | `Arcana/Features/Spreads/` |
| — | Card detail (flow from 2a/2d rows) | `Arcana/Features/CardDetail/` |
| — | Settings (behind the avatar, per 1b) | `Arcana/Features/Settings/` |

Haptics follow the wireframe notes: **soft** on save, **tick** on card flip /
selection, **rigid** on streak milestones. Ambient animation: the daily card
floats and breathes gold on a 6s loop; export button shimmers; stars twinkle.

## Building

Requires **Xcode 15+** (iOS 17 deployment target) and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
cd app
xcodegen generate        # produces Arcana.xcodeproj
open Arcana.xcodeproj
```

In Xcode's **Signing & Capabilities** tab, pick your team, then build & run the
`Arcana` scheme. The Supabase SPM package resolves on first open.

> **Free / personal Apple accounts:** the project ships configured for a free
> team — a single app target with **no widgets, App Group, or Sign in with
> Apple** (all three require the paid Developer Program, and a personal team
> can't provision them — installing an app that declares them fails with
> `CoreDeviceError 3002`). The app is fully functional this way; it persists to
> its own container and runs the seeded local ledger.
>
> If the bundle ID `com.arcana.app` is rejected, change
> `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` to something unique (e.g.
> `com.<you>.arcana`) and re-run `xcodegen generate`.

> **Paid Developer accounts:** to turn on widgets, App Groups and Sign in with
> Apple, uncomment the marked blocks in `project.yml` (instructions inline) and
> re-run `xcodegen generate`. The widget + entitlements source is already in the
> repo under `ArcanaWidgets/` and `Arcana/Resources/*.entitlements`.

### Card art & fonts (optional but recommended)

Out of the box the app streams the public-domain Rider–Waite–Smith scans from
Wikimedia Commons (cached), with a procedural cosmic card face as the offline
fallback. To bundle everything for offline use and App Store submission:

```bash
cd app
./scripts/fetch-card-art.sh
xcodegen generate
```

The same script fetches the Playfair Display / Nunito fonts (SIL OFL). Without
them the app falls back to the system serif/rounded designs.

## Supabase (sync + auth)

The app runs in **local-ledger mode** by default (seeded demo data, no account,
no network). The Supabase Swift package is currently **not linked**, so sync is
off — this keeps the build free of SPM-resolution friction.

**To turn sync on:** uncomment the `packages` block and the `dependencies` entry
in `project.yml`, run `xcodegen generate`, and let Xcode resolve the package.
All the sync/auth code is guarded by `#if canImport(Supabase)` and reactivates
itself automatically once the package is linked — no source edits needed. Then:

1. Run `supabase/schema.sql` in your project's SQL editor (skip if your web app
   already has equivalent tables — instead adjust the table/column names in
   `Arcana/Services/SupabaseService.swift`).
2. Provide credentials, either by editing `Arcana/Config/AppConfig.swift`, or by
   adding a `Secrets.plist` to the app target:

   ```xml
   <key>SUPABASE_URL</key><string>https://xyz.supabase.co</string>
   <key>SUPABASE_ANON_KEY</key><string>eyJ…</string>
   ```

3. For **Sign in with Apple**: enable the Apple provider in Supabase Auth and
   add the capability's key/team IDs per the
   [Supabase docs](https://supabase.com/docs/guides/auth/social-login/auth-apple).
   Email/password works with no extra configuration.

With credentials present the onboarding shows Apple + email sign-in and all
entries sync through row-level-secured `pulls` / `spreads` tables.

## AI insights

Insights are composed on-device from each card's keyword data (so the feature
works offline, collapsed-by-default per the design). To use a real model, point
`InsightService.remoteEndpoint` at an HTTPS endpoint (e.g. a Supabase Edge
Function) that accepts `{card, orientation, note}` and returns `{insight}`.

## Deep links

- `arcana://log` — opens the quick-log sheet (used by widgets)
- `arcana://journal` — opens the journal tab
- `arcana://today` — opens the home tab
