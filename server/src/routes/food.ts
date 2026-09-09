import { Router } from "express";
import { z } from "zod";
import { searchFoods } from "../food.js";

export const foodRouter = Router();

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
