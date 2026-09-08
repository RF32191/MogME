# MogMe iOS

Full Xcode project for the live App Store app (`Fermoselle.MogME-AI`, App Store ID 6757411615).

Open `ios/MogMe.xcodeproj` on a Mac with Xcode 16+.

## Lifetime price

The paywall loads **MogMe.Lifetime.60** (Apple ID `6758647492`, reference name `47`) through StoreKit 2 and shows Apple’s live price. It does not hardcode $4.99. Local StoreKit testing uses `MogMe/Resources/Products.storekit`.

## Workouts

Japanese walking (3 min brisk / 3 min easy) and interval cardio share `WorkoutLocationEngine`:

- Core Location callbacks hop to the main actor before any `@Published` / map update
- GPS points are filtered for stale caches, bad accuracy, and teleports
- Route arrays are capped so long sessions cannot balloon and crash

## Diet

Meal photos are written under the app Documents sandbox. Calories come from Open Food Facts plus `Resources/foods.json`. A package photo uses on-device Vision OCR, then a name search — no generative calorie AI.

## Siri

Shortcuts: look up food calories, start Japanese walking, start interval cardio, ask Wingman.

## Wingman

Social → AI Wingman sends a compressed chat screenshot (768px, JPEG 0.55, `detail: low`) plus a short on-device partner memory to `POST /wingman/advise`. Railway token caps live in `WINGMAN_*` env vars.
