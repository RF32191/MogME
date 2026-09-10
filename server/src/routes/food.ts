import { Router } from "express";
import { z } from "zod";
import { identifyFoodFromImage, searchFoods } from "../food.js";

export const foodRouter = Router();

foodRouter.post("/identify", async (req, res) => {
  const parsed = z
    .object({
      userKey: z.string().min(1).max(80).optional(),
      imageDataUrl: z.string().max(1_200_000).optional(),
      ocrText: z.string().max(4000).optional(),
      labels: z.array(z.string().max(80)).max(8).optional(),
    })
    .safeParse(req.body ?? {});
  if (!parsed.success) {
    res.status(400).json({ error: "bad-request" });
    return;
  }
  if (!parsed.data.imageDataUrl && !(parsed.data.ocrText ?? "").trim() && !(parsed.data.labels ?? []).length) {
    res.status(400).json({ error: "need-photo" });
    return;
  }
  const result = await identifyFoodFromImage(parsed.data);
  if (!result.ok && result.reason === "daily-request-cap") {
    res.status(429).json(result);
    return;
  }
  res.json(result);
});

foodRouter.get("/search", async (req, res) => {
  const parsed = z.object({ q: z.string().min(2).max(80) }).safeParse({ q: req.query.q });
  if (!parsed.success) {
    res.status(400).json({ error: "bad-query" });
    return;
  }
  try {
    const foods = await searchFoods(parsed.data.q);
    res.json({
      query: parsed.data.q,
      analysis: foods[0]?.analysis ?? `No standard nutrition found for “${parsed.data.q}”.`,
      foods,
    });
  } catch {
    res.status(502).json({ error: "food-lookup-failed" });
  }
});
