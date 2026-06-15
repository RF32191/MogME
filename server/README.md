# MogME Mog-Off Server

Backend for the MogME head-to-head "mog-off": matchmaking + a 3-round duel.

1. **Face round** — both players scan on-device, send up only their PSL **score** (0–10) plus an **already distorted + watermarked** image. The server moderates that image, then relays the *opponent's* distorted image to each player. The true face never leaves the device.
2. **Cognition round** — synchronized trivia/cognitive puzzles; score by correct answers with a speed tiebreak.
3. **AI rizz round** — both players speed-date the **same** AI persona under identical conditions; first to push the affection meter to the threshold wins.

Winner of the match = best of the 3 rounds → ELO + leaderboard update.

## Run

```bash
cd server
npm install
cp .env.example .env   # optionally add OPENAI_API_KEY for the real rizz model
npm run dev            # ws://localhost:8787/ws, http://localhost:8787/health
```

Without `OPENAI_API_KEY` the rizz round uses a local heuristic so everything still runs.

## HTTP API

- `POST /auth/signin` `{ handle, appleSub? }` → `{ user }` (use `user.id` for WS auth)
- `POST /auth/consent` `{ userId }` → records biometric/image-sharing consent
- `GET  /leaderboard?limit=50` → ranked players
- `GET  /health`

## WebSocket protocol (`/ws`)

Client → server: `auth`, `queue.join`, `queue.leave`, `face.submit`, `cognition.answer`, `rizz.message`
Server → client: `auth.ok`, `queue.joined`, `match.found`, `round.start`, `face.opponent`, `round.result`, `rizz.reply`, `rizz.opponentProgress`, `match.complete`, `error`

## Production checklist (not done in this MVP)

- Swap the in-memory `store` for Postgres (users/matches/results) + Redis (queue, leaderboard, ephemeral round state).
- Verify Sign in with Apple identity tokens in `/auth/signin`.
- Wire real image moderation (Hive/Sightengine/Rekognition) **and** a CSAM pipeline (PhotoDNA/Safer) in `moderation.ts`; the stub fails closed when moderation is enabled.
- Object storage + CDN for images if you retain them beyond a single match.
- Rate limiting, auth on the WS upgrade, and per-user match indexing.
