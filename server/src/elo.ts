import { config } from "./config.js";

/** Expected score for player A vs B given their ELO ratings. */
export function expectedScore(a: number, b: number): number {
  return 1 / (1 + Math.pow(10, (b - a) / 400));
}

/**
 * Returns the new ratings for [a, b] given the outcome.
 * outcome = 1 (a wins), 0 (b wins), 0.5 (tie).
 */
export function applyElo(a: number, b: number, outcome: number): [number, number] {
  const ea = expectedScore(a, b);
  const eb = expectedScore(b, a);
  const newA = Math.round(a + config.eloK * (outcome - ea));
  const newB = Math.round(b + config.eloK * (1 - outcome - eb));
  return [newA, newB];
}
