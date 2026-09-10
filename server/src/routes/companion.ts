import { Router } from "express";
import { z } from "zod";
import { companionReply } from "../companion.js";

/** AI Companion chat — stateless; the client holds persona + history on-device. */
export const companionRouter = Router();

const Body = z.object({
  userKey: z.string().min(1).max(80).optional(),
  persona: z.object({
    name: z.string().min(1).max(40),
    age: z.number().int().min(18).max(99),
    tone: z.enum(["friend", "supportive", "flirty", "romantic"]),
    style: z.string().max(60).optional(),
    traits: z.array(z.string().max(40)).max(12).optional(),
    interests: z.array(z.string().max(40)).max(12).optional(),
    bio: z.string().max(400).optional(),
    mode: z.enum(["standard", "meetCute"]).optional(),
    scenario: z.string().max(80).optional(),
  }),
  history: z
    .array(z.object({ role: z.enum(["user", "assistant"]), content: z.string().max(2000) }))
    .max(40)
    .optional(),
  text: z.string().max(1000),
});

companionRouter.post("/message", async (req, res) => {
  const parsed = Body.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "bad-request" });
    return;
  }
  const { persona, history, text, userKey } = parsed.data;
  const result = await companionReply(persona, history ?? [], text, userKey ?? "anon");
  if (!result.ok && (result.reason === "daily-request-cap" || result.reason === "daily-token-cap")) {
    res.status(429).json(result);
    return;
  }
  res.json(result);
});
