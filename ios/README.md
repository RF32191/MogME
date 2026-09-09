# MogMe iOS

Full Xcode project for the live App Store app (`Fermoselle.MogME-AI`, App Store ID 6757411615).

Open `ios/MogMe.xcodeproj` on a Mac with Xcode 16+.

## Lifetime price

The paywall loads **MogMe.Lifetime.60** at **$4.99** (Apple ID `6758647492`). Purchase, Restore, Apple Pay, and unfinished StoreKit transactions all grant the same premium flag. The Xcode scheme points at `MogMe/Resources/Products.storekit` so the product exists in the Simulator environment.

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
