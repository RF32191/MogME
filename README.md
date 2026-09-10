# MogME

Lifestyle iOS app plus the Railway mog-off / rizz / companion / wingman server.

## iOS

The Xcode project with the $4.99 lifetime and Tokens.Mogme pack lives only on the `cursor/mogme-ios-lifetime-wingman-cccc` branch, under [`ios/MogMe.xcodeproj`](ios/README.md). GitHub `main` is server-only. Running the App Store app on your phone will not pick up those UI changes — open that `.xcodeproj` after checking out the branch. See [`ios/README.md`](ios/README.md).

## Server

```bash
cd server
npm install
cp .env.example .env
npm run dev
```

New wingman routes:

- `POST /wingman/advise` — evaluate a chat, draft replies, or give a texting strategy
- `GET  /wingman/usage?userKey=` — remaining daily token budget
