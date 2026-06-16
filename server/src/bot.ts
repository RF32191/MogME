import { nanoid } from "nanoid";
import { store } from "./store.js";
import type { CognitionRoundState, User } from "./types.js";

/**
 * AI competitor ("bot") used as a fallback opponent when matchmaking can't find
 * a real human within the timeout. Bots are real `User` records (so the match
 * flow treats them like anyone else) but are flagged `isBot` and excluded from
 * the leaderboard, and are deleted when their match ends.
 *
 * The bot plays each round server-side with realistic timing and human-like,
 * beatable skill — it should win some and lose some.
 */

const BOT_HANDLES = [
  "ApexRival", "NightOwl", "GoldenBoy", "VelvetEdge", "IronJaw", "AceMogger",
  "SilentK", "RogueChin", "PrimeViz", "LuxLion", "OnyxAce", "ZenMax",
  "BladeRunner", "TitanV", "EchoFox", "NovaStrike", "DapperWolf", "KingTide",
];

export function isBotId(id: string): boolean {
  return id.startsWith("bot_");
}

/** Create + persist a bot user with ELO near the given target. */
export function createBotUser(nearElo: number): User {
  const handle = BOT_HANDLES[Math.floor(Math.random() * BOT_HANDLES.length)] ?? "Rival";
  // Within ~±120 of the player's ELO so it feels like a fair, ranked opponent.
  const jitter = Math.round((Math.random() - 0.5) * 240);
  const elo = Math.max(100, nearElo + jitter);
  const games = 20 + Math.floor(Math.random() * 380);
  const winRate = 0.4 + Math.random() * 0.25;
  const wins = Math.round(games * winRate);
  const bot: User = {
    id: `bot_${nanoid(10)}`,
    handle: `${handle}${Math.floor(Math.random() * 90 + 10)}`,
    elo,
    wins,
    losses: games - wins,
    createdAt: Date.now(),
    consentedAt: Date.now(),
    isBot: true,
  };
  store.saveUser(bot);
  return bot;
}

/** A plausible PSL face score (0-10) for the bot, loosely tied to its ELO. */
export function botFaceScore(elo: number): number {
  // Higher ELO bots tend to score a bit higher, but with wide variance so the
  // player can win or lose. Center ~6.3 at ELO 1000.
  const base = 5.3 + (elo - 1000) / 600; // ~±0.8 across a typical band
  const noise = (Math.random() - 0.5) * 2.6;
  return clamp(base + noise, 3.2, 9.4);
}

/**
 * Generate the bot's answers for a cognition round: each question answered with
 * a skill-based probability of being correct, with randomized "thinking" times.
 */
export function botCognitionAnswers(
  state: CognitionRoundState,
  elo: number,
): { questionId: string; choiceIndex: number; msElapsed: number }[] {
  // Skill 0..1 — chance of answering each question correctly.
  const skill = clamp(0.45 + (elo - 1000) / 1600 + (Math.random() - 0.5) * 0.15, 0.3, 0.9);
  let elapsed = 800 + Math.random() * 1500;
  return state.questions.map((q) => {
    const correct = Math.random() < skill;
    let choiceIndex = q.answerIndex;
    if (!correct) {
      const wrong = q.choices.map((_, i) => i).filter((i) => i !== q.answerIndex);
      choiceIndex = wrong[Math.floor(Math.random() * wrong.length)] ?? q.answerIndex;
    }
    elapsed += 1500 + Math.random() * 4500; // 1.5-6s per question
    return { questionId: q.id, choiceIndex, msElapsed: Math.round(elapsed) };
  });
}

/**
 * Plausible per-target reaction times (ms) for the bot in a reflex duel. Higher
 * ELO → faster average, with enough variance that the player can win or lose.
 */
export function botReflexTimes(elo: number, count: number): number[] {
  // Center ~320ms at ELO 1000; ~±100ms across a typical band.
  const base = clamp(320 - (elo - 1000) / 12, 200, 470);
  return Array.from({ length: count }, () =>
    Math.round(clamp(base + (Math.random() - 0.4) * 170, 150, 900)),
  );
}

/**
 * A plausible best punch speed (m/s) for the bot. Higher ELO punches a bit
 * harder, with variance so the player can win or lose.
 */
export function botPunchSpeed(elo: number): number {
  // Center ~6.5 m/s at ELO 1000; casual punches land 4–9 m/s on-device.
  const base = clamp(6.5 + (elo - 1000) / 250, 4.5, 10.5);
  return Math.round(clamp(base + (Math.random() - 0.45) * 3.0, 3, 13) * 100) / 100;
}

/** One scheduled "message" the bot lands during a rizz round. */
export interface BotRizzStep {
  /** ms from round start when this step fires. */
  atMs: number;
  /** the bot's affection after this step (0-100). */
  affection: number;
  /** the bot's turn count after this step. */
  turns: number;
}

/**
 * Plan the bot's rizz round as a series of affection gains over time, so the
 * human sees a live rival climbing toward the win threshold. Higher-ELO bots
 * charm faster and are more likely to reach the threshold first.
 */
export function botRizzPlan(elo: number, startedAt: number, deadline: number, threshold: number): BotRizzStep[] {
  const totalMs = Math.max(1000, deadline - startedAt);
  const skill = clamp(0.4 + (elo - 1000) / 1600 + (Math.random() - 0.5) * 0.15, 0.25, 0.9);
  // Does the bot fully win them over? More skill → more likely.
  const reaches = Math.random() < skill;
  const finalAffection = reaches
    ? threshold
    : Math.round(clamp(40 + skill * 50 + (Math.random() - 0.5) * 20, 25, threshold - 4));

  const stepCount = 5 + Math.floor(Math.random() * 4); // 5–8 "messages"
  const steps: BotRizzStep[] = [];
  // First message lands a few seconds in; spread the rest across the round with jitter.
  let t = 3500 + Math.random() * 4000;
  for (let i = 0; i < stepCount; i++) {
    const frac = (i + 1) / stepCount;
    const affection = Math.round(20 + (finalAffection - 20) * frac);
    const atMs = Math.min(t, totalMs - 1500);
    steps.push({ atMs, affection, turns: i + 1 });
    if (atMs >= totalMs - 1500) break;
    t += (totalMs / stepCount) * (0.7 + Math.random() * 0.6);
  }
  return steps;
}

function clamp(n: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, n));
}
