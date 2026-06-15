import { Router } from "express";
import { z } from "zod";
import { store } from "../store.js";
import { leaderboardStore } from "../db.js";

export const leaderboardRouter = Router();

// --- Existing Mog-Off ELO board ------------------------------------------

leaderboardRouter.get("/", (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const board = store.leaderboard(limit).map((u, i) => ({
    rank: i + 1,
    handle: u.handle,
    elo: u.elo,
    wins: u.wins,
    losses: u.losses,
  }));
  res.json({ leaderboard: board });
});

// --- Usernames -----------------------------------------------------------

const Username = z
  .string()
  .trim()
  .min(3)
  .max(20)
  .regex(/^[A-Za-z0-9_]+$/, "letters, numbers and underscore only");

leaderboardRouter.get("/username/check", async (req, res) => {
  const parsed = Username.safeParse(req.query.u);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid-username" });
    return;
  }
  const ownerId = typeof req.query.ownerId === "string" ? req.query.ownerId : undefined;
  await leaderboardStore.ready();
  const available = await leaderboardStore.checkUsername(parsed.data, ownerId);
  res.json({ available });
});

const ClaimBody = z.object({
  ownerId: z.string().min(8).max(64),
  username: Username,
  share: z.boolean().optional(),
});

leaderboardRouter.post("/username/claim", async (req, res) => {
  const parsed = ClaimBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid-body", details: parsed.error.flatten() });
    return;
  }
  await leaderboardStore.ready();
  const result = await leaderboardStore.claimUsername(
    parsed.data.ownerId,
    parsed.data.username,
    parsed.data.share ?? true,
  );
  if (!result.ok) {
    res.status(409).json({ error: "username-taken" });
    return;
  }
  res.json({ ok: true, username: parsed.data.username });
});

// --- Score submission (owner-verified) -----------------------------------

const SubmitBase = z.object({
  ownerId: z.string().min(8).max(64),
  username: Username,
});

async function ensureOwner(username: string, ownerId: string, res: import("express").Response): Promise<boolean> {
  await leaderboardStore.ready();
  const ok = await leaderboardStore.verifyOwner(username, ownerId);
  if (!ok) {
    res.status(403).json({ error: "not-username-owner" });
    return false;
  }
  return true;
}

const CognitionSubmit = SubmitBase.extend({ score: z.number().min(0).max(100) });

leaderboardRouter.post("/cognition/submit", async (req, res) => {
  const parsed = CognitionSubmit.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid-body" });
    return;
  }
  if (!(await ensureOwner(parsed.data.username, parsed.data.ownerId, res))) return;
  await leaderboardStore.upsertCognition(parsed.data.ownerId, parsed.data.username, parsed.data.score);
  res.json({ ok: true });
});

const FacialSubmit = SubmitBase.extend({ psl: z.number().min(0).max(10) });

leaderboardRouter.post("/facial/submit", async (req, res) => {
  const parsed = FacialSubmit.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid-body" });
    return;
  }
  if (!(await ensureOwner(parsed.data.username, parsed.data.ownerId, res))) return;
  await leaderboardStore.upsertFacial(parsed.data.ownerId, parsed.data.username, parsed.data.psl);
  res.json({ ok: true });
});

const RizzGoal = z.enum(["open", "number", "date", "recover"]);
const RizzDifficulty = z.enum(["easy", "medium", "hard"]);

const RizzSubmit = SubmitBase.extend({
  goal: RizzGoal,
  difficulty: RizzDifficulty,
  timeToCloseMs: z.number().int().min(0),
  turns: z.number().int().min(0),
  score: z.number().min(0).max(100),
});

leaderboardRouter.post("/rizz/submit", async (req, res) => {
  const parsed = RizzSubmit.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid-body" });
    return;
  }
  if (!(await ensureOwner(parsed.data.username, parsed.data.ownerId, res))) return;
  await leaderboardStore.upsertRizz(
    parsed.data.ownerId,
    parsed.data.username,
    parsed.data.goal,
    parsed.data.difficulty,
    parsed.data.timeToCloseMs,
    parsed.data.turns,
    parsed.data.score,
  );
  res.json({ ok: true });
});

// --- Board fetch ---------------------------------------------------------

const clampLimit = (raw: unknown) => Math.min(Math.max(Number(raw) || 50, 1), 200);

leaderboardRouter.get("/cognition", async (req, res) => {
  await leaderboardStore.ready();
  res.json({ leaderboard: await leaderboardStore.topCognition(clampLimit(req.query.limit)) });
});

leaderboardRouter.get("/facial", async (req, res) => {
  await leaderboardStore.ready();
  res.json({ leaderboard: await leaderboardStore.topFacial(clampLimit(req.query.limit)) });
});

leaderboardRouter.get("/rizz", async (req, res) => {
  const goal = RizzGoal.safeParse(req.query.goal);
  const difficulty = RizzDifficulty.safeParse(req.query.difficulty);
  if (!goal.success || !difficulty.success) {
    res.status(400).json({ error: "invalid-filters" });
    return;
  }
  await leaderboardStore.ready();
  res.json({
    leaderboard: await leaderboardStore.topRizz(goal.data, difficulty.data, clampLimit(req.query.limit)),
  });
});
