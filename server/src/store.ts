import { nanoid } from "nanoid";
import { config } from "./config.js";
import type { Match, User } from "./types.js";

/**
 * In-memory store for the MVP. Interfaces are intentionally narrow so this can be
 * swapped for Postgres (users, matches, results) + Redis (matchmaking queue,
 * leaderboard sorted set, ephemeral match state) without touching call sites.
 */
class MemoryStore {
  private users = new Map<string, User>();
  private usersByApple = new Map<string, string>();
  private matches = new Map<string, Match>();

  // --- Users ---
  createUser(input: { handle: string; appleSub?: string }): User {
    if (input.appleSub) {
      const existingId = this.usersByApple.get(input.appleSub);
      if (existingId) {
        const existing = this.users.get(existingId);
        if (existing) return existing;
      }
    }
    const user: User = {
      id: nanoid(),
      handle: input.handle,
      appleSub: input.appleSub,
      elo: config.eloStart,
      wins: 0,
      losses: 0,
      createdAt: Date.now(),
    };
    this.users.set(user.id, user);
    if (input.appleSub) this.usersByApple.set(input.appleSub, user.id);
    return user;
  }

  getUser(id: string): User | undefined {
    return this.users.get(id);
  }

  /** Insert a pre-built user (used for AI bot competitors). */
  saveUser(user: User): void {
    this.users.set(user.id, user);
  }

  deleteUser(id: string): void {
    this.users.delete(id);
  }

  updateUser(id: string, patch: Partial<User>): User | undefined {
    const user = this.users.get(id);
    if (!user) return undefined;
    Object.assign(user, patch);
    return user;
  }

  leaderboard(limit = 50): User[] {
    return [...this.users.values()]
      .filter((u) => !u.isBot)
      .sort((a, b) => b.elo - a.elo)
      .slice(0, limit);
  }

  // --- Matches ---
  saveMatch(match: Match): void {
    this.matches.set(match.id, match);
  }

  getMatch(id: string): Match | undefined {
    return this.matches.get(id);
  }

  deleteMatch(id: string): void {
    this.matches.delete(id);
  }
}

export const store = new MemoryStore();
