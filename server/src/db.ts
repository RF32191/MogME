import pg from "pg";

/**
 * Persistence for the global leaderboards + unique usernames.
 *
 * Uses Postgres when DATABASE_URL is set (Railway injects this once a Postgres
 * plugin is attached). Falls back to an in-memory store otherwise so local dev
 * and un-provisioned deploys keep working (scores are then ephemeral).
 */

export interface BoardRow {
  rank: number;
  username: string;
  value: number;
  detail?: Record<string, number>;
}

export interface ClaimResult {
  ok: boolean;
  reason?: "taken";
}

export interface LeaderboardStore {
  ready(): Promise<void>;
  /** true => the username is free (or already owned by this owner). */
  checkUsername(username: string, ownerId?: string): Promise<boolean>;
  claimUsername(ownerId: string, username: string, share: boolean): Promise<ClaimResult>;
  verifyOwner(username: string, ownerId: string): Promise<boolean>;
  upsertCognition(ownerId: string, username: string, score: number): Promise<void>;
  upsertFacial(ownerId: string, username: string, psl: number): Promise<void>;
  upsertRizz(
    ownerId: string,
    username: string,
    goal: string,
    difficulty: string,
    timeToCloseMs: number,
    turns: number,
    score: number,
  ): Promise<void>;
  topCognition(limit: number): Promise<BoardRow[]>;
  topFacial(limit: number): Promise<BoardRow[]>;
  topRizz(goal: string, difficulty: string, limit: number): Promise<BoardRow[]>;
}

const norm = (u: string) => u.trim().toLowerCase();

// --- Postgres implementation ---------------------------------------------

class PgStore implements LeaderboardStore {
  private pool: pg.Pool;
  private initialized: Promise<void> | null = null;

  constructor(connectionString: string) {
    const isLocal = /localhost|127\.0\.0\.1/.test(connectionString);
    this.pool = new pg.Pool({
      connectionString,
      ssl: isLocal ? false : { rejectUnauthorized: false },
    });
  }

  ready(): Promise<void> {
    if (!this.initialized) this.initialized = this.migrate();
    return this.initialized;
  }

  private async migrate(): Promise<void> {
    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS accounts (
        owner_id        text PRIMARY KEY,
        username        text NOT NULL,
        username_lower  text NOT NULL UNIQUE,
        share           boolean NOT NULL DEFAULT true,
        created_at      bigint NOT NULL
      );
      CREATE TABLE IF NOT EXISTS cognition_scores (
        owner_id   text PRIMARY KEY,
        username   text NOT NULL,
        best       integer NOT NULL,
        updated_at bigint NOT NULL
      );
      CREATE TABLE IF NOT EXISTS facial_scores (
        owner_id   text PRIMARY KEY,
        username   text NOT NULL,
        best_psl   real NOT NULL,
        updated_at bigint NOT NULL
      );
      CREATE TABLE IF NOT EXISTS rizz_scores (
        owner_id          text NOT NULL,
        goal              text NOT NULL,
        difficulty        text NOT NULL,
        username          text NOT NULL,
        time_to_close_ms  integer NOT NULL,
        turns             integer NOT NULL,
        score             integer NOT NULL,
        updated_at        bigint NOT NULL,
        PRIMARY KEY (owner_id, goal, difficulty)
      );
    `);
  }

  async checkUsername(username: string, ownerId?: string): Promise<boolean> {
    const { rows } = await this.pool.query<{ owner_id: string }>(
      "SELECT owner_id FROM accounts WHERE username_lower = $1",
      [norm(username)],
    );
    if (rows.length === 0) return true;
    return Boolean(ownerId) && rows[0]!.owner_id === ownerId;
  }

  async claimUsername(ownerId: string, username: string, share: boolean): Promise<ClaimResult> {
    const available = await this.checkUsername(username, ownerId);
    if (!available) return { ok: false, reason: "taken" };
    // Free the owner's previous username (if they are renaming) then upsert.
    await this.pool.query("DELETE FROM accounts WHERE owner_id = $1", [ownerId]);
    await this.pool.query(
      `INSERT INTO accounts (owner_id, username, username_lower, share, created_at)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (username_lower) DO UPDATE SET username = EXCLUDED.username, share = EXCLUDED.share`,
      [ownerId, username.trim(), norm(username), share, Date.now()],
    );
    return { ok: true };
  }

  async verifyOwner(username: string, ownerId: string): Promise<boolean> {
    const { rows } = await this.pool.query<{ owner_id: string }>(
      "SELECT owner_id FROM accounts WHERE username_lower = $1",
      [norm(username)],
    );
    return rows.length > 0 && rows[0]!.owner_id === ownerId;
  }

  async upsertCognition(ownerId: string, username: string, score: number): Promise<void> {
    await this.pool.query(
      `INSERT INTO cognition_scores (owner_id, username, best, updated_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (owner_id) DO UPDATE
         SET best = GREATEST(cognition_scores.best, EXCLUDED.best),
             username = EXCLUDED.username, updated_at = EXCLUDED.updated_at`,
      [ownerId, username, Math.round(score), Date.now()],
    );
  }

  async upsertFacial(ownerId: string, username: string, psl: number): Promise<void> {
    await this.pool.query(
      `INSERT INTO facial_scores (owner_id, username, best_psl, updated_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (owner_id) DO UPDATE
         SET best_psl = GREATEST(facial_scores.best_psl, EXCLUDED.best_psl),
             username = EXCLUDED.username, updated_at = EXCLUDED.updated_at`,
      [ownerId, username, psl, Date.now()],
    );
  }

  async upsertRizz(
    ownerId: string,
    username: string,
    goal: string,
    difficulty: string,
    timeToCloseMs: number,
    turns: number,
    score: number,
  ): Promise<void> {
    // Keep the fastest close (lowest time) for this owner/goal/difficulty.
    await this.pool.query(
      `INSERT INTO rizz_scores (owner_id, goal, difficulty, username, time_to_close_ms, turns, score, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (owner_id, goal, difficulty) DO UPDATE
         SET time_to_close_ms = LEAST(rizz_scores.time_to_close_ms, EXCLUDED.time_to_close_ms),
             turns = CASE WHEN EXCLUDED.time_to_close_ms < rizz_scores.time_to_close_ms THEN EXCLUDED.turns ELSE rizz_scores.turns END,
             score = CASE WHEN EXCLUDED.time_to_close_ms < rizz_scores.time_to_close_ms THEN EXCLUDED.score ELSE rizz_scores.score END,
             username = EXCLUDED.username, updated_at = EXCLUDED.updated_at`,
      [ownerId, goal, difficulty, username, Math.round(timeToCloseMs), Math.round(turns), Math.round(score), Date.now()],
    );
  }

  async topCognition(limit: number): Promise<BoardRow[]> {
    const { rows } = await this.pool.query<{ username: string; best: number }>(
      `SELECT s.username, s.best FROM cognition_scores s
       JOIN accounts a ON a.owner_id = s.owner_id AND a.share = true
       ORDER BY s.best DESC, s.updated_at ASC LIMIT $1`,
      [limit],
    );
    return rows.map((r, i) => ({ rank: i + 1, username: r.username, value: r.best }));
  }

  async topFacial(limit: number): Promise<BoardRow[]> {
    const { rows } = await this.pool.query<{ username: string; best_psl: number }>(
      `SELECT s.username, s.best_psl FROM facial_scores s
       JOIN accounts a ON a.owner_id = s.owner_id AND a.share = true
       ORDER BY s.best_psl DESC, s.updated_at ASC LIMIT $1`,
      [limit],
    );
    return rows.map((r, i) => ({ rank: i + 1, username: r.username, value: Number(r.best_psl) }));
  }

  async topRizz(goal: string, difficulty: string, limit: number): Promise<BoardRow[]> {
    const { rows } = await this.pool.query<{
      username: string;
      time_to_close_ms: number;
      turns: number;
      score: number;
    }>(
      `SELECT s.username, s.time_to_close_ms, s.turns, s.score FROM rizz_scores s
       JOIN accounts a ON a.owner_id = s.owner_id AND a.share = true
       WHERE s.goal = $1 AND s.difficulty = $2
       ORDER BY s.time_to_close_ms ASC, s.turns ASC, s.score DESC LIMIT $3`,
      [goal, difficulty, limit],
    );
    return rows.map((r, i) => ({
      rank: i + 1,
      username: r.username,
      value: r.time_to_close_ms,
      detail: { turns: r.turns, score: r.score },
    }));
  }
}

// --- In-memory fallback ---------------------------------------------------

class MemoryStore implements LeaderboardStore {
  private accounts = new Map<string, { username: string; share: boolean }>(); // ownerId -> account
  private byUsername = new Map<string, string>(); // username_lower -> ownerId
  private cognition = new Map<string, { username: string; best: number; at: number }>();
  private facial = new Map<string, { username: string; psl: number; at: number }>();
  private rizz = new Map<string, { username: string; ms: number; turns: number; score: number; at: number }>();

  async ready(): Promise<void> {}

  async checkUsername(username: string, ownerId?: string): Promise<boolean> {
    const existing = this.byUsername.get(norm(username));
    if (!existing) return true;
    return Boolean(ownerId) && existing === ownerId;
  }

  async claimUsername(ownerId: string, username: string, share: boolean): Promise<ClaimResult> {
    if (!(await this.checkUsername(username, ownerId))) return { ok: false, reason: "taken" };
    const prev = this.accounts.get(ownerId);
    if (prev) this.byUsername.delete(norm(prev.username));
    this.accounts.set(ownerId, { username: username.trim(), share });
    this.byUsername.set(norm(username), ownerId);
    return { ok: true };
  }

  async verifyOwner(username: string, ownerId: string): Promise<boolean> {
    return this.byUsername.get(norm(username)) === ownerId;
  }

  async upsertCognition(ownerId: string, username: string, score: number): Promise<void> {
    const cur = this.cognition.get(ownerId);
    const best = Math.max(cur?.best ?? 0, Math.round(score));
    this.cognition.set(ownerId, { username, best, at: Date.now() });
  }

  async upsertFacial(ownerId: string, username: string, psl: number): Promise<void> {
    const cur = this.facial.get(ownerId);
    this.facial.set(ownerId, { username, psl: Math.max(cur?.psl ?? 0, psl), at: Date.now() });
  }

  async upsertRizz(
    ownerId: string,
    username: string,
    goal: string,
    difficulty: string,
    timeToCloseMs: number,
    turns: number,
    score: number,
  ): Promise<void> {
    const key = `${ownerId}:${goal}:${difficulty}`;
    const cur = this.rizz.get(key);
    if (!cur || timeToCloseMs < cur.ms) {
      this.rizz.set(key, { username, ms: Math.round(timeToCloseMs), turns, score, at: Date.now() });
    } else {
      this.rizz.set(key, { ...cur, username });
    }
  }

  private shared(ownerId: string): boolean {
    return this.accounts.get(ownerId)?.share ?? false;
  }

  async topCognition(limit: number): Promise<BoardRow[]> {
    return [...this.cognition.entries()]
      .filter(([owner]) => this.shared(owner))
      .sort((a, b) => b[1].best - a[1].best || a[1].at - b[1].at)
      .slice(0, limit)
      .map(([, v], i) => ({ rank: i + 1, username: v.username, value: v.best }));
  }

  async topFacial(limit: number): Promise<BoardRow[]> {
    return [...this.facial.entries()]
      .filter(([owner]) => this.shared(owner))
      .sort((a, b) => b[1].psl - a[1].psl || a[1].at - b[1].at)
      .slice(0, limit)
      .map(([, v], i) => ({ rank: i + 1, username: v.username, value: v.psl }));
  }

  async topRizz(goal: string, difficulty: string, limit: number): Promise<BoardRow[]> {
    return [...this.rizz.entries()]
      .filter(([key, _v]) => {
        const owner = key.split(":")[0]!;
        return key.endsWith(`:${goal}:${difficulty}`) && this.shared(owner);
      })
      .sort((a, b) => a[1].ms - b[1].ms || a[1].turns - b[1].turns || b[1].score - a[1].score)
      .slice(0, limit)
      .map(([, v], i) => ({
        rank: i + 1,
        username: v.username,
        value: v.ms,
        detail: { turns: v.turns, score: v.score },
      }));
  }
}

const connectionString = process.env.DATABASE_URL ?? "";
export const leaderboardStore: LeaderboardStore = connectionString
  ? new PgStore(connectionString)
  : new MemoryStore();

if (!connectionString) {
  console.log("  ⚠ No DATABASE_URL set — leaderboards use the in-memory fallback (ephemeral).");
}

// Kick off migrations at import time; routes also await ready() defensively.
leaderboardStore.ready().catch((err) => console.error("leaderboard store init failed:", err));
