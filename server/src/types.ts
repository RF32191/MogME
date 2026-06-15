import type { RoundName } from "./config.js";

export interface User {
  id: string;
  handle: string;
  /** Sign in with Apple subject (sub claim) when available; otherwise a device id. */
  appleSub?: string;
  elo: number;
  wins: number;
  losses: number;
  createdAt: number;
  /** Whether the user has accepted the biometric/image-sharing consent. */
  consentedAt?: number;
  /** True for server-driven AI competitors (excluded from the leaderboard). */
  isBot?: boolean;
}

export interface RoundResult {
  round: RoundName;
  /** userId -> numeric score for that round (higher wins). */
  scores: Record<string, number>;
  winnerId: string | null; // null = tie
}

export type MatchPhase =
  | "pairing"
  | "face"
  | "cognition"
  | "rizz"
  | "complete"
  | "abandoned";

export interface MatchPlayer {
  userId: string;
  handle: string;
  elo: number;
  connected: boolean;
}

export interface Match {
  id: string;
  players: [MatchPlayer, MatchPlayer];
  phase: MatchPhase;
  /** Rounds requested for this match (subset/order of config.rounds). */
  rounds: RoundName[];
  roundIndex: number;
  results: RoundResult[];
  createdAt: number;
  /** Per-round volatile state keyed by round name. */
  state: {
    face?: FaceRoundState;
    cognition?: CognitionRoundState;
    rizz?: RizzRoundState;
  };
  winnerId?: string | null;
}

export interface FaceRoundState {
  /** userId -> PSL score (0-10) computed on-device, sent up. */
  submittedScore: Record<string, number>;
  /** userId -> distorted+watermarked image (data URL or storage key). */
  distortedImage: Record<string, string>;
  /** userId -> moderation verdict for their image. */
  moderation: Record<string, "pending" | "approved" | "rejected">;
  deadline: number;
}

export interface CognitionQuestion {
  id: string;
  prompt: string;
  choices: string[];
  /** index into choices; never sent to clients. */
  answerIndex: number;
}

export interface CognitionRoundState {
  questions: CognitionQuestion[];
  /** userId -> array of { questionId, choiceIndex, msElapsed }. */
  answers: Record<string, { questionId: string; choiceIndex: number; msElapsed: number }[]>;
  startedAt: number;
  deadline: number;
}

export interface RizzMessage {
  role: "user" | "ai";
  content: string;
  affectionAfter: number;
  at: number;
}

export interface RizzPlayerState {
  affection: number; // 0-100
  turns: number;
  transcript: RizzMessage[];
  /** ms from round start to reaching the win threshold; undefined if not reached. */
  wonAtMs?: number;
  busy: boolean; // a completion is in-flight (prevents turn spamming)
}

export interface RizzRoundState {
  persona: RizzPersona;
  byUser: Record<string, RizzPlayerState>;
  startedAt: number;
  deadline: number;
}

export interface RizzPersona {
  id: string;
  name: string;
  /** Short public blurb shown to the player. */
  bio: string;
  /** System prompt fragment describing personality + what wins them over. */
  systemPersona: string;
}
