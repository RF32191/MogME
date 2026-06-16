import { config } from "../config.js";
import type { Match, PunchRoundState, RoundResult } from "../types.js";

/** Sane clamp for a submitted punch speed in m/s (rejects garbage / cheats). */
const MAX_PUNCH_MS = 25; // pro boxers ~11 m/s at the fist; allow headroom
const MIN_PUNCH_MS = 0;

export function initPunchRound(): PunchRoundState {
  const startedAt = Date.now();
  return {
    attempts: Math.max(1, config.punchAttempts),
    bestByUser: {},
    startedAt,
    deadline: startedAt + config.punchRoundMs,
  };
}

export function serializePunch(state: PunchRoundState) {
  return { attempts: state.attempts };
}

/**
 * Record a punch speed (m/s), measured on-device. We keep the player's best.
 * Late submissions after the deadline are ignored.
 */
export function submitPunch(
  state: PunchRoundState,
  userId: string,
  speed: number,
): { ok: boolean; reason?: string } {
  if (Date.now() > state.deadline) return { ok: false, reason: "round-over" };
  const clean = Number.isFinite(speed) ? Math.max(MIN_PUNCH_MS, Math.min(MAX_PUNCH_MS, speed)) : 0;
  const prev = state.bestByUser[userId] ?? 0;
  if (clean > prev) state.bestByUser[userId] = clean;
  else if (state.bestByUser[userId] === undefined) state.bestByUser[userId] = clean;
  return { ok: true };
}

/** True once both players have logged at least one punch. */
export function bothPunched(state: PunchRoundState, match: Match): boolean {
  return match.players.every((p) => state.bestByUser[p.userId] !== undefined);
}

/** Score = best punch speed (m/s); the harder/faster punch wins. */
export function resolvePunchRound(state: PunchRoundState, match: Match): RoundResult {
  const scores: Record<string, number> = {};
  for (const player of match.players) {
    scores[player.userId] = Math.round((state.bestByUser[player.userId] ?? 0) * 100) / 100;
  }
  const [a, b] = match.players;
  const sa = scores[a.userId] ?? 0;
  const sb = scores[b.userId] ?? 0;
  let winnerId: string | null = null;
  if (sa > sb) winnerId = a.userId;
  else if (sb > sa) winnerId = b.userId;
  return { round: "punch", scores, winnerId };
}
