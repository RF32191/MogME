# MogMe iOS

This is the Xcode project that contains the $4.99 lifetime and Tokens.Mogme changes. The App Store / TestFlight icon on your phone is a **different binary**. GitHub `main` has **no iOS project** — only the Railway server — so server-side food/AI changes show up in the live app, but crown and token UI changes do not until you run **this** project.

## Run this build on your iPhone

1. Do **not** run these from `~`. Either `cd` into an existing MogME clone, or clone it first:
   ```bash
   cd ~
   git clone https://github.com/RF32191/MogME.git
   cd MogME
   git fetch origin
   git checkout cursor/mogme-ios-lifetime-wingman-cccc
   git pull origin cursor/mogme-ios-lifetime-wingman-cccc
   open ios/MogMe.xcodeproj
   ```
   That opens `/Users/<you>/MogME/ios/MogMe.xcodeproj`.
2. Close any other MogMe Xcode window (the original App Store source).
3. Confirm the Xcode title bar says **MogMe** and the path includes `MogME/ios/MogMe.xcodeproj`.
4. Scheme: **MogMe**. Destination: your iPhone.
5. Product → Clean Build Folder, then Run (⌘R).
6. Home must show **v1.5 · Lifetime $4.99 · 100 tokens $0.99**. If you still see $59.99 or Watch an ad, Xcode ran the old app, not this project.

## Archive and submit this project

The file to open in Xcode is:

**`ios/MogMe.xcodeproj`**

Full path on this repo: `MogME/ios/MogMe.xcodeproj` (after you clone or pull `cursor/mogme-ios-lifetime-wingman-cccc`).

Then in Xcode:

1. Scheme **MogMe**, Any iOS Device (arm64).
2. Product → Archive.
3. Distribute App → App Store Connect.
4. In App Store Connect, attach consumable **Tokens.Mogme** (`6810475672`) to this version and submit.

Bundle ID is `Fermoselle.MogME-AI` (same as the store app). Xcode will replace the store install while you debug. After you stop, opening the home-screen icon can launch the last Xcode build — delete the app and reinstall from the store if you want the live build back.

## Lifetime price

The crown paywall always shows **$4.99** for **MogMe.Lifetime.60** (Apple ID `6758647492`, reference `47`). It never displays the old $59.99 / $60 list price. Purchase, Restore, offer-code redemption (`LIFETIMEACCESS` / Lifetime Unlock), and unfinished StoreKit transactions all grant the same premium flag. The scheme StoreKit file is `ios/MogMe/Resources/Products.storekit`.

## AI tokens

`Tokens.Mogme` is set up the same way as lifetime in `Resources/Products.storekit`. Submit this consumable in App Store Connect with the next app version:

| Field | Value |
| --- | --- |
| Type | Consumable |
| Product ID | `Tokens.Mogme` |
| Reference Name | `54` |
| Apple ID | `6810475672` |
| Display Name | 100 AI Tokens |
| Description | 100 AI tokens for Rizz, Companion, Wingman, and Mog-Off. |
| Price | $0.99 (100 tokens) |

No other token packs. No watch-an-ad. No Unlimited. 1 token = 1 Rizz / Companion / Wingman / Mog-Off message. Users get 5 free tokens every day. The same row sits under the crown paywall next to One-Time-Purchase.

## Workouts

Japanese walking (3 min brisk / 3 min easy) and interval cardio share `WorkoutLocationEngine`:

- Core Location callbacks hop to the main actor before any `@Published` / map update
- GPS points are filtered for stale caches, bad accuracy, and teleports
- Route arrays are capped so long sessions cannot balloon and crash

## Diet

Live camera capture (AVFoundation) shows a full-screen loading overlay while the photo is described. You can edit that description or retake, then calories come from Open Food Facts — not an AI guess. Photos stay in the app sandbox.

## Siri

Shortcuts: look up food calories, start Japanese walking, start interval cardio, ask Wingman.

## Wingman

Social → AI Wingman is a real thread. A live or library chat screenshot is compressed, sent as vision input, and billed (~85 image tokens + reply). Railway caps live in `WINGMAN_*` env vars.
