import { nanoid } from "nanoid";
import { config, type RoundName } from "./config.js";
import { store } from "./store.js";
import { applyElo } from "./elo.js";
import type { Match, MatchPlayer, RoundResult, User } from "./types.js";
import { initFaceRound, resolveFaceRound } from "./rounds/face.js";
import { initCognitionRound, resolveCognitionRound } from "./rounds/cognition.js";
import { initReflexRound, resolveReflexRound } from "./rounds/reflex.js";
import { initPunchRound, resolvePunchRound } from "./rounds/punch.js";
import { initRizzRound, resolveRizzRound } from "./rounds/rizz.js";

export function createMatch(userA: User, userB: User, rounds: RoundName[] = [...config.rounds]): Match {
  const players: [MatchPlayer, MatchPlayer] = [
    { userId: userA.id, handle: userA.handle, elo: userA.elo, connected: true },
    { userId: userB.id, handle: userB.handle, elo: userB.elo, connected: true },
  ];
  const match: Match = {
    id: nanoid(),
    players,
    phase: "pairing",
    rounds,
    roundIndex: -1,
    results: [],
    createdAt: Date.now(),
    state: {},
  };
  store.saveMatch(match);
  return match;
}

/** Advance to the next round (or to completion). Returns the new phase. */
export function advanceMatch(match: Match): Match["phase"] {
  match.roundIndex += 1;
  if (match.roundIndex >= match.rounds.length) {
    finalizeMatch(match);
    return match.phase;
  }
  const round = match.rounds[match.roundIndex]!;
  match.phase = round;
  switch (round) {
    case "face":
      match.state.face = initFaceRound();
      break;
    case "cognition":
      match.state.cognition = initCognitionRound();
      break;
    case "reflex":
      match.state.reflex = initReflexRound();
      break;
    case "punch":
      match.state.punch = initPunchRound();
      break;
    case "rizz":
      match.state.rizz = initRizzRound();
      break;
  }
  store.saveMatch(match);
  return match.phase;
}

export function resolveCurrentRound(match: Match): RoundResult | null {
  const round = match.rounds[match.roundIndex];
  let result: RoundResult | null = null;
  if (round === "face" && match.state.face) result = resolveFaceRound(match.state.face, match);
  else if (round === "cognition" && match.state.cognition) result = resolveCognitionRound(match.state.cognition, match);
  else if (round === "reflex" && match.state.reflex) result = resolveReflexRound(match.state.reflex, match);
  else if (round === "punch" && match.state.punch) result = resolvePunchRound(match.state.punch, match);
  else if (round === "rizz" && match.state.rizz) result = resolveRizzRound(match.state.rizz, match);
  if (result) {
    match.results.push(result);
    store.saveMatch(match);
  }
  return result;
}

export interface FinalResult {
  winnerId: string | null;
  roundsWon: Record<string, number>;
  eloChange: Record<string, number>;
}

export function finalizeMatch(match: Match): FinalResult {
  const [a, b] = match.players;
  const roundsWon: Record<string, number> = { [a.userId]: 0, [b.userId]: 0 };
  for (const r of match.results) {
    if (r.winnerId) roundsWon[r.winnerId] = (roundsWon[r.winnerId] ?? 0) + 1;
  }

  let winnerId: string | null = null;
  if (roundsWon[a.userId]! > roundsWon[b.userId]!) winnerId = a.userId;
  else if (roundsWon[b.userId]! > roundsWon[a.userId]!) winnerId = b.userId;

  // ELO update (0.5 outcome on a tie).
  const outcome = winnerId === a.userId ? 1 : winnerId === b.userId ? 0 : 0.5;
  const [newA, newB] = applyElo(a.elo, b.elo, outcome);
  const eloChange: Record<string, number> = { [a.userId]: newA - a.elo, [b.userId]: newB - b.elo };

  const userA = store.getUser(a.userId);
  const userB = store.getUser(b.userId);
  if (userA) {
    userA.elo = newA;
    if (winnerId === a.userId) userA.wins += 1;
    else if (winnerId) userA.losses += 1;
  }
  if (userB) {
    userB.elo = newB;
    if (winnerId === b.userId) userB.wins += 1;
    else if (winnerId) userB.losses += 1;
  }

  match.phase = "complete";
  match.winnerId = winnerId;

  // Delete any retained face images the moment the match ends — they are only
  // ever needed live during the face round (already relayed to each opponent),
  // so nothing about a finished match should hold a player's likeness.
  purgeMatchImages(match);
  store.saveMatch(match);

  // Drop the rest of the ephemeral round state and the match record shortly after,
  // once clients have fetched their final results.
  scheduleCleanup(match.id);

  return { winnerId, roundsWon, eloChange };
}

/** Immediately strip any stored/distorted face images from a match's state. */
export function purgeMatchImages(match: Match): void {
  if (match.state.face) {
    match.state.face.distortedImage = {};
    match.state.face.moderation = {};
  }
}

function scheduleCleanup(matchId: string): void {
  setTimeout(() => {
    const m = store.getMatch(matchId);
    if (m) {
      m.state = {};
      store.saveMatch(m);
    }
    // Fully evict the match record so nothing lingers in memory.
    store.deleteMatch(matchId);
  }, config.imageRetentionMs).unref?.();
}
