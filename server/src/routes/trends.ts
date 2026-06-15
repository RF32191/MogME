import { Router } from "express";
import { z } from "zod";
import { getTrends } from "../trends.js";

/** Current men's style/grooming trends (LLM-generated, cached daily). */
export const trendsRouter = Router();

const Query = z.object({
  faceShape: z
    .enum(["oval", "round", "square", "heart", "diamond", "oblong", "triangle"])
    .optional(),
});

trendsRouter.get("/current", async (req, res) => {
  const parsed = Query.safeParse(req.query);
  const faceShape = parsed.success ? parsed.data.faceShape : undefined;
  try {
    const result = await getTrends(faceShape);
    res.json(result);
  } catch {
    res.status(500).json({ error: "trends-failed" });
  }
});
