# MogME

Lifestyle iOS app plus the Railway mog-off / rizz / companion / wingman server.

## iOS

The full Xcode project is in [`ios/`](ios/README.md) (`Fermoselle.MogME-AI`).

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
