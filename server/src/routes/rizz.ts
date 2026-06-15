import { Router } from "express";
import { z } from "zod";
import {
  startPractice,
  getSession,
  practiceTurn,
  generateReport,
  goalList,
} from "../practice.js";

/** Standalone single-player "Rizz Trainer" practice mode (separate from mog-off). */
export const rizzRouter = Router();

rizzRouter.get("/practice/goals", (_req, res) => {
  res.json({ goals: goalList() });
});

const StartBody = z.object({
  goal: z.enum(["open", "number", "date", "recover"]).optional(),
  difficulty: z.enum(["easy", "medium", "hard"]).optional(),
  personaId: z.string().optional(),
});

rizzRouter.post("/practice/start", (req, res) => {
  const parsed = StartBody.safeParse(req.body ?? {});
  if (!parsed.success) {
    res.status(400).json({ error: "bad-request" });
    return;
  }
  const s = startPractice(parsed.data.goal ?? "open", parsed.data.difficulty ?? "medium", parsed.data.personaId);
  res.json({
    sessionId: s.id,
    persona: { name: s.persona.name, bio: s.persona.bio },
    goal: s.goal,
    difficulty: s.difficulty,
    affection: s.affection,
    turns: s.turns,
    maxTurns: s.maxTurns,
    winThreshold: 100,
  });
});

const MsgBody = z.object({ sessionId: z.string(), text: z.string() });

rizzRouter.post("/practice/message", async (req, res) => {
  const parsed = MsgBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "bad-request" });
    return;
  }
  const session = getSession(parsed.data.sessionId);
  if (!session) {
    res.status(404).json({ error: "session-not-found" });
    return;
  }
  const result = await practiceTurn(session, parsed.data.text);
  res.json(result);
});

const ReportBody = z.object({ sessionId: z.string() });

rizzRouter.post("/practice/report", async (req, res) => {
  const parsed = ReportBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "bad-request" });
    return;
  }
  const session = getSession(parsed.data.sessionId);
  if (!session) {
    res.status(404).json({ error: "session-not-found" });
    return;
  }
  const report = await generateReport(session);
  res.json(report);
});
