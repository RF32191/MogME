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

function clamp(n: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, n));
}
