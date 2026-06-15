import type { Server } from "node:http";
import { WebSocketServer, WebSocket } from "ws";
import { z } from "zod";
import { store } from "./store.js";
import { matchmaker } from "./matchmaking.js";
import {
  advanceMatch,
  resolveCurrentRound,
  finalizeMatch,
  purgeMatchImages,
} from "./match.js";
import type { Match } from "./types.js";
import { submitFace, bothSubmitted, opponentImageFor } from "./rounds/face.js";
import { serializeQuestions, submitAnswer, allAnswered } from "./rounds/cognition.js";
import { rizzTurn } from "./rounds/rizz.js";
import { isBotId, botFaceScore, botCognitionAnswers } from "./bot.js";

/** userId -> live socket */
const sockets = new Map<string, WebSocket>();
/** matchId -> timeout handles for the active round */
const roundTimers = new Map<string, NodeJS.Timeout>();
/** matchId -> timeout handle for the bot's scheduled action this round */
const botTimers = new Map<string, NodeJS.Timeout>();

const ClientMsg = z.discriminatedUnion("type", [
  z.object({ type: z.literal("auth"), userId: z.string() }),
  z.object({ type: z.literal("queue.join"), rounds: z.array(z.enum(["face", "cognition", "rizz"])).optional() }),
  z.object({ type: z.literal("queue.leave") }),
  z.object({ type: z.literal("face.submit"), score: z.number(), distortedImage: z.string() }),
  z.object({ type: z.literal("cognition.answer"), questionId: z.string(), choiceIndex: z.number().int() }),
  z.object({ type: z.literal("rizz.message"), text: z.string() }),
]);

function send(userId: string, payload: unknown): void {
  const ws = sockets.get(userId);
  if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(payload));
}

function broadcast(match: Match, build: (userId: string) => unknown): void {
  for (const p of match.players) send(p.userId, build(p.userId));
}

function opponentOf(match: Match, userId: string) {
  return match.players.find((p) => p.userId !== userId);
}

export function attachWebSocket(server: Server): void {
  const wss = new WebSocketServer({ server, path: "/ws" });

  matchmaker.onMatch = (match) => startMatch(match);

  wss.on("connection", (ws) => {
    let userId: string | null = null;

    ws.on("message", async (data) => {
      let msg: z.infer<typeof ClientMsg>;
      try {
        msg = ClientMsg.parse(JSON.parse(data.toString()));
      } catch {
        ws.send(JSON.stringify({ type: "error", reason: "bad-message" }));
        return;
      }

      if (msg.type === "auth") {
        const user = store.getUser(msg.userId);
        if (!user) {
          ws.send(JSON.stringify({ type: "error", reason: "unknown-user" }));
          return;
        }
        userId = user.id;
        sockets.set(userId, ws);
        ws.send(JSON.stringify({ type: "auth.ok", user }));
        return;
      }

      if (!userId) {
        ws.send(JSON.stringify({ type: "error", reason: "not-authed" }));
        return;
      }

      switch (msg.type) {
        case "queue.join":
          matchmaker.enqueue(userId, msg.rounds);
          send(userId, { type: "queue.joined" });
          break;
        case "queue.leave":
          matchmaker.dequeue(userId);
          send(userId, { type: "queue.left" });
          break;
        case "face.submit":
          await handleFaceSubmit(userId, msg.score, msg.distortedImage);
          break;
        case "cognition.answer":
          handleCognitionAnswer(userId, msg.questionId, msg.choiceIndex);
          break;
        case "rizz.message":
          await handleRizzMessage(userId, msg.text);
          break;
      }
    });

    ws.on("close", () => {
      if (userId) {
        sockets.delete(userId);
        matchmaker.dequeue(userId);
        // If the user drops mid-match, never keep their (or the opponent's)
        // images around for an unfinished, abandoned game.
        const match = activeMatchFor(userId);
        if (match && match.phase !== "complete") {
          purgeMatchImages(match);
          store.saveMatch(match);
        }
      }
    });
  });
}

// --- Match lifecycle ---

function activeMatchFor(userId: string): Match | undefined {
  // MVP: scan store. In production, maintain a userId->matchId index.
  // We only need the user's in-progress match.
  // (store has no list API by design; we track via a small index here.)
  return userMatchIndex.get(userId);
}

const userMatchIndex = new Map<string, Match>();

function startMatch(match: Match): void {
  for (const p of match.players) userMatchIndex.set(p.userId, match);
  broadcast(match, (uid) => {
    const opp = opponentOf(match, uid)!;
    return {
      type: "match.found",
      matchId: match.id,
      rounds: match.rounds,
      opponent: { handle: opp.handle, elo: opp.elo, isBot: isBotId(opp.userId) },
    };
  });
  startNextRound(match);
}

function startNextRound(match: Match): void {
  const phase = advanceMatch(match);
  if (phase === "complete") return; // finalize already broadcast by caller path

  if (phase === "face" && match.state.face) {
    broadcast(match, () => ({ type: "round.start", round: "face", deadline: match.state.face!.deadline }));
    armTimer(match, match.state.face.deadline, () => resolveAndAdvance(match));
  } else if (phase === "cognition" && match.state.cognition) {
    broadcast(match, () => ({
      type: "round.start",
      round: "cognition",
      deadline: match.state.cognition!.deadline,
      questions: serializeQuestions(match.state.cognition!),
    }));
    armTimer(match, match.state.cognition.deadline, () => resolveAndAdvance(match));
  } else if (phase === "rizz" && match.state.rizz) {
    broadcast(match, () => ({
      type: "round.start",
      round: "rizz",
      deadline: match.state.rizz!.deadline,
      persona: {
        name: match.state.rizz!.persona.name,
        bio: match.state.rizz!.persona.bio,
        winThreshold: 100,
      },
    }));
    armTimer(match, match.state.rizz.deadline, () => resolveAndAdvance(match));
  }

  scheduleBotPlay(match);
}

// --- AI competitor autoplay ---

/** If one of the players is a bot, schedule its move for the current round. */
function scheduleBotPlay(match: Match): void {
  const bot = match.players.find((p) => isBotId(p.userId));
  if (!bot) return;
  const botId = bot.userId;
  const botElo = bot.elo;
  clearBotTimer(match.id);

  if (match.phase === "face" && match.state.face) {
    const deadline = match.state.face.deadline;
    const t = setTimeout(() => {
      const face = match.state.face;
      if (match.phase !== "face" || !face) return;
      if (face.submittedScore[botId] === undefined) {
        face.submittedScore[botId] = botFaceScore(botElo);
        face.moderation[botId] = "approved"; // bot has no real image to relay
      }
      if (bothSubmitted(face, match)) resolveAndAdvance(match);
    }, botDelay(deadline, 6000, 16000));
    t.unref?.();
    botTimers.set(match.id, t);
  } else if (match.phase === "cognition" && match.state.cognition) {
    const deadline = match.state.cognition.deadline;
    const t = setTimeout(() => {
      const cog = match.state.cognition;
      if (match.phase !== "cognition" || !cog) return;
      if (!cog.answers[botId] || cog.answers[botId]!.length === 0) {
        cog.answers[botId] = botCognitionAnswers(cog, botElo);
      }
      if (allAnswered(cog, match)) resolveAndAdvance(match);
    }, botDelay(deadline, 9000, 22000));
    t.unref?.();
    botTimers.set(match.id, t);
  }
}

/** A randomized delay within [lo, hi] that always lands before the deadline. */
function botDelay(deadline: number, lo: number, hi: number): number {
  const span = Math.max(0, deadline - Date.now() - 2000);
  const target = lo + Math.random() * (hi - lo);
  return span > 0 ? Math.min(target, span) : 0;
}

function clearBotTimer(matchId: string): void {
  const t = botTimers.get(matchId);
  if (t) clearTimeout(t);
  botTimers.delete(matchId);
}

function armTimer(match: Match, deadline: number, fn: () => void): void {
  clearTimer(match.id);
  const t = setTimeout(fn, Math.max(0, deadline - Date.now()));
  t.unref?.();
  roundTimers.set(match.id, t);
}

function clearTimer(matchId: string): void {
  const t = roundTimers.get(matchId);
  if (t) clearTimeout(t);
  roundTimers.delete(matchId);
}

function resolveAndAdvance(match: Match): void {
  clearTimer(match.id);
  clearBotTimer(match.id);
  const result = resolveCurrentRound(match);
  if (result) broadcast(match, () => ({ type: "round.result", result }));

  // The face round is decided on the numeric PSL scores only; once it resolves,
  // both players have already received each other's outline, so the stored
  // images are immediately purged (well before the 5-min match cleanup).
  if (result?.round === "face") purgeMatchImages(match);

  if (match.roundIndex + 1 >= match.rounds.length) {
    const final = finalizeMatch(match);
    broadcast(match, () => ({ type: "match.complete", final, results: match.results }));
    for (const p of match.players) {
      userMatchIndex.delete(p.userId);
      if (isBotId(p.userId)) store.deleteUser(p.userId); // bots are ephemeral
    }
  } else {
    startNextRound(match);
  }
}

// --- Round handlers ---

async function handleFaceSubmit(userId: string, score: number, distortedImage: string): Promise<void> {
  const match = activeMatchFor(userId);
  if (!match || match.phase !== "face" || !match.state.face) {
    send(userId, { type: "error", reason: "no-face-round" });
    return;
  }
  const res = await submitFace(match.state.face, userId, { score, distortedImage });
  send(userId, { type: "face.ack", ok: res.ok, reason: res.reason });

  // Relay our approved distorted image to the opponent (if approved).
  const opp = opponentOf(match, userId)!;
  const imgForOpp = opponentImageFor(match.state.face, match, opp.userId);
  if (imgForOpp) send(opp.userId, { type: "face.opponent", image: imgForOpp });

  if (bothSubmitted(match.state.face, match)) resolveAndAdvance(match);
}

function handleCognitionAnswer(userId: string, questionId: string, choiceIndex: number): void {
  const match = activeMatchFor(userId);
  if (!match || match.phase !== "cognition" || !match.state.cognition) {
    send(userId, { type: "error", reason: "no-cognition-round" });
    return;
  }
  const res = submitAnswer(match.state.cognition, userId, questionId, choiceIndex);
  send(userId, { type: "cognition.ack", ok: res.ok, reason: res.reason });
  if (allAnswered(match.state.cognition, match)) resolveAndAdvance(match);
}

async function handleRizzMessage(userId: string, text: string): Promise<void> {
  const match = activeMatchFor(userId);
  if (!match || match.phase !== "rizz" || !match.state.rizz) {
    send(userId, { type: "error", reason: "no-rizz-round" });
    return;
  }
  const res = await rizzTurn(match.state.rizz, userId, text);
  send(userId, {
    type: "rizz.reply",
    ok: res.ok,
    reason: res.reason,
    reply: res.reply,
    affection: res.affection,
    turns: res.turns,
    won: res.won,
  });
  // Let the opponent see the rival's progress (affection only, not their chat).
  const opp = opponentOf(match, userId)!;
  if (res.ok && res.affection !== undefined) {
    send(opp.userId, { type: "rizz.opponentProgress", affection: res.affection, turns: res.turns });
  }
  // First to win ends the round immediately.
  if (res.won) resolveAndAdvance(match);
}
