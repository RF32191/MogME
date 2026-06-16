import { config } from "../config.js";
import type { Match, ReflexRoundState, RoundResult } from "../types.js";

/** Penalty (ms) recorded for a missed target or a false start. */
const MISS_PENALTY_MS = 2000;
/** Clamp bounds for a single legitimate reaction time. */
const MIN_REACTION_MS = 80;
const MAX_REACTION_MS = 2000;

export function initReflexRound(): ReflexRoundState {
  const startedAt = Date.now();
  const count = Math.max(1, config.reflexTargetCount);
  const delays: number[] = [];
  for (let i = 0; i < count; i++) {
    // Each target appears after a random 0.8–3.0s wait so it can't be anticipated.
    delays.push(800 + Math.floor(Math.random() * 2200));
  }
  return {
    targetCount: count,
    delays,
    submissions: {},
    startedAt,
    deadline: startedAt + config.reflexRoundMs,
  };
}

/** Client-safe view of the round (the shared flash schedule). */
export function serializeReflex(state: ReflexRoundState) {
  return { targetCount: state.targetCount, delays: state.delays };
}

/**
 * Record a player's reaction times (measured on-device). Values are sanitized
 * and padded so a malformed/short submission can't win. One submission per player.
 */
export function submitReflex(
  state: ReflexRoundState,
  userId: string,
  times: number[],
): { ok: boolean; reason?: string } {
  if (Date.now() > state.deadline) return { ok: false, reason: "round-over" };
  if (state.submissions[userId]) return { ok: false, reason: "already-submitted" };

  const clean = (times ?? []).slice(0, state.targetCount).map((t) => {
    if (!Number.isFinite(t) || t <= 0) return MISS_PENALTY_MS; // miss / false start
    return Math.max(MIN_REACTION_MS, Math.min(MAX_REACTION_MS, Math.round(t)));
  });
  while (clean.length < state.targetCount) clean.push(MISS_PENALTY_MS);
  state.submissions[userId] = clean;
  return { ok: true };
}

export function bothReflexSubmitted(state: ReflexRoundState, match: Match): boolean {
  return match.players.every((p) => state.submissions[p.userId] !== undefined);
}

/**
 * Score = average reaction time in ms (LOWER is better). The winner is the
 * faster player; the stored score is the raw average so the UI can show "ms".
 */
export function resolveReflexRound(state: ReflexRoundState, match: Match): RoundResult {
  const scores: Record<string, number> = {};
  for (const player of match.players) {
    const times = state.submissions[player.userId] ?? Array(state.targetCount).fill(MISS_PENALTY_MS);
    const avg = times.reduce((sum, t) => sum + t, 0) / Math.max(1, times.length);
    scores[player.userId] = Math.round(avg);
  }
  const [a, b] = match.players;
  const sa = scores[a.userId] ?? MISS_PENALTY_MS;
  const sb = scores[b.userId] ?? MISS_PENALTY_MS;
  let winnerId: string | null = null;
  if (sa < sb) winnerId = a.userId;       // faster (lower ms) wins
  else if (sb < sa) winnerId = b.userId;
  return { round: "reflex", scores, winnerId };
}
