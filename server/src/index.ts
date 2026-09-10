import http from "node:http";
import express from "express";
import cors from "cors";
import { config } from "./config.js";
import { authRouter } from "./routes/auth.js";
import { leaderboardRouter } from "./routes/leaderboard.js";
import { rizzRouter } from "./routes/rizz.js";
import { companionRouter } from "./routes/companion.js";
import { trendsRouter } from "./routes/trends.js";
import { wingmanRouter } from "./routes/wingman.js";
import { foodRouter } from "./routes/food.js";
import { aiBudget, aiUsagePayload, creditPurchasedTokens } from "./tokens.js";
import { attachWebSocket } from "./ws.js";

const app = express();
app.use(cors());
app.use(express.json({ limit: "8mb" })); // distorted images arrive as data URLs

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    rounds: config.rounds,
    rizzModel: config.openaiApiKey ? config.rizzModel : "heuristic (no OPENAI_API_KEY)",
    wingmanModel: config.openaiApiKey ? config.wingmanModel : "heuristic (no OPENAI_API_KEY)",
    aiDailyRequestCap: config.aiDailyRequestCap,
    aiDailyTokenCap: config.aiDailyTokenCap,
    googleFoodId: Boolean(config.googleVisionApiKey || (config.googleCseApiKey && config.googleCseCx)),
    moderation: config.moderationEnabled ? config.moderationProvider : "disabled",
  });
});

app.use("/auth", authRouter);
app.use("/leaderboard", leaderboardRouter);
app.use("/rizz", rizzRouter);
app.use("/companion", companionRouter);
app.use("/trends", trendsRouter);
app.use("/wingman", wingmanRouter);
app.use("/food", foodRouter);

app.get("/ai/usage", (req, res) => {
  const userKey = String(req.query.userKey ?? "anon").slice(0, 80);
  const used = aiBudget.snapshot(userKey);
  const remaining = aiBudget.remaining(userKey);
  res.json({
    used,
    remaining,
    usage: aiUsagePayload(userKey),
    dailyRequestCap: config.aiDailyRequestCap,
    dailyTokenCap: config.aiDailyTokenCap,
    note: "Wingman, companion, and rizz trainer share this daily cap. Not unlimited.",
  });
});

app.post("/ai/credit", (req, res) => {
  const userKey = String(req.body?.userKey ?? "anon").slice(0, 80);
  const tokens = Number(req.body?.tokens ?? 0);
  if (!Number.isFinite(tokens) || tokens <= 0 || tokens > 100_000) {
    res.status(400).json({ error: "bad-tokens" });
    return;
  }
  const purchased = creditPurchasedTokens(userKey, tokens);
  res.json({ ok: true, purchased, usage: aiUsagePayload(userKey) });
});

const server = http.createServer(app);
attachWebSocket(server);

server.listen(config.port, () => {
  console.log(`MogME mog-off server listening on :${config.port}`);
  console.log(`  WebSocket:   ws://localhost:${config.port}/ws`);
  console.log(`  Health:      http://localhost:${config.port}/health`);
  if (!config.openaiApiKey) {
    console.log("  ⚠ No OPENAI_API_KEY set — AI rizz round uses the heuristic fallback.");
  }
  if (!config.moderationEnabled) {
    console.log("  ⚠ Moderation disabled — enable + wire a provider before production.");
  }
});
