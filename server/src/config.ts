import "dotenv/config";

function num(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export const config = {
  port: num("PORT", 8787),

  // Rounds in a full match, in order. Each can also be played standalone.
  rounds: ["face", "cognition", "reflex", "punch", "rizz"] as const,

  // Round timing (ms)
  faceRoundTimeoutMs: num("FACE_ROUND_TIMEOUT_MS", 60_000),
  cognitionRoundMs: num("COGNITION_ROUND_MS", 45_000),
  cognitionQuestionCount: num("COGNITION_QUESTION_COUNT", 5),
  reflexRoundMs: num("REFLEX_ROUND_MS", 40_000),
  reflexTargetCount: num("REFLEX_TARGET_COUNT", 5),
  punchRoundMs: num("PUNCH_ROUND_MS", 40_000),
  punchAttempts: num("PUNCH_ATTEMPTS", 3),
  rizzRoundMs: num("RIZZ_ROUND_MS", 120_000),
  rizzMaxTurns: num("RIZZ_MAX_TURNS", 12),
  rizzWinThreshold: num("RIZZ_WIN_THRESHOLD", 100),

  // Matchmaking
  matchmakingTierBand: num("MATCHMAKING_TIER_BAND", 200), // ELO band for skill matching
  matchmakingMaxWaitMs: num("MATCHMAKING_MAX_WAIT_MS", 15_000), // widen band after this

  // AI competitor: if no human opponent is found within this window, pair the
  // waiting player with a server-driven bot so they can still play.
  botEnabled: process.env.BOT_ENABLED !== "false",
  botMatchTimeoutMs: num("BOT_MATCH_TIMEOUT_MS", 60_000),

  // ELO
  eloK: num("ELO_K", 32),
  eloStart: num("ELO_START", 1000),

  // LLM (AI rizz + wingman). gpt-4o-mini keeps Railway token cost low.
  openaiApiKey: process.env.OPENAI_API_KEY ?? "",
  rizzModel: process.env.RIZZ_MODEL ?? "gpt-4o-mini",
  wingmanModel: process.env.WINGMAN_MODEL ?? process.env.RIZZ_MODEL ?? "gpt-4o-mini",
  wingmanMaxTokens: num("WINGMAN_MAX_TOKENS", 280),
  wingmanDailyRequestCap: num("WINGMAN_DAILY_REQUEST_CAP", 40),
  wingmanDailyTokenCap: num("WINGMAN_DAILY_TOKEN_CAP", 50_000),

  // Moderation (image + text). Wire real providers via these.
  moderationEnabled: process.env.MODERATION_ENABLED === "true",
  moderationProvider: process.env.MODERATION_PROVIDER ?? "stub", // "stub" | "openai" | "hive" | "sightengine"

  // Uploaded distorted-face image retention (ms). Short by default to limit liability.
  imageRetentionMs: num("IMAGE_RETENTION_MS", 5 * 60_000),
} as const;

export type RoundName = (typeof config.rounds)[number];
