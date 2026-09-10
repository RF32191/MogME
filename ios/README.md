# MogMe iOS

Full Xcode project for the live App Store app (`Fermoselle.MogME-AI`, App Store ID 6757411615).

Open `ios/MogMe.xcodeproj` on a Mac with Xcode 16+.

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
