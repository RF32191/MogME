# MogMe iOS

This is the Xcode project that contains the $4.99 lifetime and Tokens.Mogme changes. The App Store / TestFlight icon on your phone is a **different binary**. GitHub `main` has **no iOS project** — only the Railway server — so server-side food/AI changes show up in the live app, but crown and token UI changes do not until you run **this** project.

## Run this build on your iPhone

1. In Terminal, in your MogME clone:
   ```bash
   git fetch origin
   git checkout cursor/mogme-ios-lifetime-wingman-cccc
   git pull origin cursor/mogme-ios-lifetime-wingman-cccc
   ```
2. Close any other MogMe Xcode window (the original App Store source).
3. Open **this** file: `ios/MogMe.xcodeproj` (not a project from another folder).
4. Scheme: **MogMe**. Destination: your iPhone.
5. Product → Clean Build Folder, then Run (⌘R).
6. Home must show **v1.5 · Lifetime $4.99 · 100 tokens $0.99**. If you still see $59.99 or Watch an ad, Xcode ran the old app, not this project.

Bundle ID is `Fermoselle.MogME-AI` (same as the store app). Xcode will replace the store install while you debug. After you stop, opening the home-screen icon can launch the last Xcode build — delete the app and reinstall from the store if you want the live build back.

## Lifetime price

The crown paywall always shows **$4.99** for **MogMe.Lifetime.60** (Apple ID `6758647492`, reference `47`). It never displays the old $59.99 / $60 list price. Purchase, Restore, offer-code redemption (`LIFETIMEACCESS` / Lifetime Unlock), and unfinished StoreKit transactions all grant the same premium flag. The scheme StoreKit file is `ios/MogMe/Resources/Products.storekit`.

## AI tokens

`Tokens.Mogme` (Apple ID `6810475672`, reference `54`) is the only token pack: **100 tokens for $0.99**. There is no watch-an-ad row and no Unlimited option. 1 token = 1 Rizz / Companion / Wingman / Mog-Off message. Users get 5 free tokens every day. The same pack is on the crown paywall, Home, and the Tokens sheet.

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
