import { config } from "../config.js";
import type { FaceRoundState, Match, RoundResult } from "../types.js";
import { moderateImage } from "../moderation.js";

export function initFaceRound(): FaceRoundState {
  return {
    submittedScore: {},
    distortedImage: {},
    moderation: {},
    deadline: Date.now() + config.faceRoundTimeoutMs,
  };
}

export interface FaceSubmission {
  /** PSL score computed on-device (0-10). */
  score: number;
  /** Distorted + watermarked face image (data URL or storage key). */
  distortedImage: string;
}

/**
 * Records a player's submission. The raw face never reaches the server: the
 * client sends only the numeric PSL score plus an already-distorted, watermarked
 * image. We still moderate that image before it can be relayed to the opponent.
 */
export async function submitFace(
  state: FaceRoundState,
  userId: string,
  submission: FaceSubmission,
): Promise<{ ok: boolean; reason?: string }> {
  if (state.submittedScore[userId] !== undefined) {
    return { ok: false, reason: "already-submitted" };
  }
  const score = clampScore(submission.score);
  state.submittedScore[userId] = score;
  state.moderation[userId] = "pending";

  const verdict = await moderateImage(submission.distortedImage);
  if (!verdict.approved) {
    state.moderation[userId] = "rejected";
    // Keep the score (it's just a number) but withhold the image from the opponent.
    return { ok: true, reason: `image-rejected:${verdict.reason ?? "unknown"}` };
  }
  state.moderation[userId] = "approved";
  state.distortedImage[userId] = submission.distortedImage;
  return { ok: true };
}

export function bothSubmitted(state: FaceRoundState, match: Match): boolean {
  return match.players.every((p) => state.submittedScore[p.userId] !== undefined);
}

export function resolveFaceRound(state: FaceRoundState, match: Match): RoundResult {
  const [a, b] = match.players;
  const scoreA = state.submittedScore[a.userId] ?? 0;
  const scoreB = state.submittedScore[b.userId] ?? 0;
  let winnerId: string | null = null;
  if (scoreA > scoreB) winnerId = a.userId;
  else if (scoreB > scoreA) winnerId = b.userId;
  return {
    round: "face",
    scores: { [a.userId]: scoreA, [b.userId]: scoreB },
    winnerId,
  };
}

/** The distorted image to show a player is their OPPONENT's approved image. */
export function opponentImageFor(state: FaceRoundState, match: Match, userId: string): string | null {
  const opponent = match.players.find((p) => p.userId !== userId);
  if (!opponent) return null;
  if (state.moderation[opponent.userId] !== "approved") return null;
  return state.distortedImage[opponent.userId] ?? null;
}

function clampScore(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(10, n));
}
