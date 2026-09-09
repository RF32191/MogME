import { Router } from "express";
import { z } from "zod";
import { adviseWingman, type WingmanGoal } from "../wingman.js";
import { aiBudget, aiUsagePayload } from "../tokens.js";

export const wingmanRouter = Router();

const Body = z.object({
  userKey: z.string().min(1).max(80).optional(),
  goal: z.enum(["evaluate", "reply", "strategy"]).optional(),
  text: z.string().max(800).optional(),
  ocrText: z.string().max(4000).optional(),
  imageDataUrl: z.string().max(1_200_000).optional(),
  memory: z
    .object({
      name: z.string().max(40).optional(),
      notes: z.string().max(240).optional(),
      style: z.string().max(80).optional(),
      facts: z.array(z.string().max(120)).max(8).optional(),
      doNots: z.array(z.string().max(80)).max(6).optional(),
      lastTopics: z.array(z.string().max(80)).max(6).optional(),
    })
    .optional(),
  history: z
    .array(z.object({ role: z.enum(["user", "assistant"]), content: z.string().max(280) }))
    .max(10)
    .optional(),
});

wingmanRouter.post("/advise", async (req, res) => {
  const parsed = Body.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "bad-request" });
    return;
  }
  const data = parsed.data;
  const result = await adviseWingman({
    userKey: data.userKey ?? "anon",
    goal: (data.goal ?? "evaluate") as WingmanGoal,
    text: data.text,
    ocrText: data.ocrText,
    imageDataUrl: data.imageDataUrl,
    memory: data.memory,
    history: data.history,
  });
  if (!result.ok && result.reason === "empty") {
    res.status(400).json(result);
    return;
  }
  if (!result.ok && (result.reason === "daily-request-cap" || result.reason === "daily-token-cap")) {
    res.status(429).json(result);
    return;
  }
  if (!result.ok) {
    res.status(400).json(result);
    return;
  }
  res.json(result);
});

function usageResponse(userKey: string) {
  const used = aiBudget.snapshot(userKey);
  const remaining = aiBudget.remaining(userKey);
  return { used, remaining, usage: aiUsagePayload(userKey) };
}

wingmanRouter.get("/usage", (req, res) => {
  const userKey = String(req.query.userKey ?? "anon").slice(0, 80);
  res.json(usageResponse(userKey));
});
