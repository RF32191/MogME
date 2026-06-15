import { config, type RoundName } from "./config.js";
import { store } from "./store.js";
import type { Match } from "./types.js";
import { createMatch } from "./match.js";
import { createBotUser } from "./bot.js";

interface QueueEntry {
  userId: string;
  enqueuedAt: number;
  /** Rounds this player wants to compete in (canonical order). */
  rounds: RoundName[];
}

/** Normalize an arbitrary round selection to the canonical order, falling back to a full match. */
export function normalizeRounds(rounds?: string[]): RoundName[] {
  const selected = (rounds ?? []).filter((r): r is RoundName =>
    (config.rounds as readonly string[]).includes(r),
  );
  const ordered = config.rounds.filter((r) => selected.includes(r));
  return ordered.length > 0 ? [...ordered] : [...config.rounds];
}

function roundsKey(rounds: RoundName[]): string {
  return rounds.join(",");
}

/**
 * Simple skill-banded matchmaking queue. Pairs the two longest-waiting users
 * whose ELO is within an (expanding) band AND who selected the same mode
 * (same set of rounds). In production this belongs in Redis with a proper
 * sorted-set search.
 */
class Matchmaker {
  private queue: QueueEntry[] = [];
  private timer: NodeJS.Timeout | null = null;

  /** Callback invoked when a match is formed. Set by the ws layer. */
  onMatch: ((match: Match) => void) | null = null;

  enqueue(userId: string, rounds?: string[]): void {
    if (this.queue.some((e) => e.userId === userId)) return;
    this.queue.push({ userId, enqueuedAt: Date.now(), rounds: normalizeRounds(rounds) });
    this.ensureTimer();
    this.tryMatch();
  }

  dequeue(userId: string): void {
    this.queue = this.queue.filter((e) => e.userId !== userId);
  }

  isQueued(userId: string): boolean {
    return this.queue.some((e) => e.userId === userId);
  }

  private ensureTimer(): void {
    if (this.timer) return;
    this.timer = setInterval(() => {
      this.tryMatch();
      this.tryBotMatch();
    }, 1000);
    this.timer.unref?.();
  }

  /**
   * Fallback: any player who has waited longer than `botMatchTimeoutMs` without a
   * human opponent is paired with a fresh AI bot near their ELO.
   */
  private tryBotMatch(): void {
    if (!config.botEnabled) return;
    const now = Date.now();
    for (const entry of [...this.queue]) {
      if (now - entry.enqueuedAt < config.botMatchTimeoutMs) continue;
      const user = store.getUser(entry.userId);
      if (!user) {
        this.dequeue(entry.userId);
        continue;
      }
      this.dequeue(entry.userId);
      const bot = createBotUser(user.elo);
      const match = createMatch(user, bot, entry.rounds);
      this.onMatch?.(match);
    }
  }

  private tryMatch(): void {
    if (this.queue.length < 2) return;
    // Oldest-first.
    const sorted = [...this.queue].sort((a, b) => a.enqueuedAt - b.enqueuedAt);

    for (let i = 0; i < sorted.length; i++) {
      const a = sorted[i]!;
      const userA = store.getUser(a.userId);
      if (!userA) {
        this.dequeue(a.userId);
        continue;
      }
      // Band widens the longer A has waited.
      const waited = Date.now() - a.enqueuedAt;
      const widen = waited > config.matchmakingMaxWaitMs ? 5 : 1;
      const band = config.matchmakingTierBand * widen;

      for (let j = i + 1; j < sorted.length; j++) {
        const b = sorted[j]!;
        const userB = store.getUser(b.userId);
        if (!userB) {
          this.dequeue(b.userId);
          continue;
        }
        // Only pair players who chose the same mode (same rounds).
        if (roundsKey(a.rounds) !== roundsKey(b.rounds)) continue;
        if (Math.abs(userA.elo - userB.elo) <= band) {
          this.dequeue(a.userId);
          this.dequeue(b.userId);
          const match = createMatch(userA, userB, a.rounds);
          this.onMatch?.(match);
          // Recurse to pair remaining users this tick.
          this.tryMatch();
          return;
        }
      }
    }
  }
}

export const matchmaker = new Matchmaker();
