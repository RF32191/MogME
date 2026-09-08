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
    moderation: config.moderationEnabled ? config.moderationProvider : "disabled",
  });
});

app.use("/auth", authRouter);
app.use("/leaderboard", leaderboardRouter);
app.use("/rizz", rizzRouter);
app.use("/companion", companionRouter);
app.use("/trends", trendsRouter);
app.use("/wingman", wingmanRouter);

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
