import { nanoid } from "nanoid";
import { config } from "../config.js";
import { TRIVIA_BANK } from "../data/trivia.js";
import type { CognitionQuestion, CognitionRoundState, Match, RoundResult } from "../types.js";

export function initCognitionRound(): CognitionRoundState {
  const questions = pickQuestions(config.cognitionQuestionCount);
  const startedAt = Date.now();
  return {
    questions,
    answers: {},
    startedAt,
    deadline: startedAt + config.cognitionRoundMs,
  };
}

function pickQuestions(count: number): CognitionQuestion[] {
  const shuffled = [...TRIVIA_BANK].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, Math.min(count, shuffled.length)).map((q) => ({ ...q, id: nanoid(8) }));
}

/** Client-safe view of the questions (answers stripped). */
export function serializeQuestions(state: CognitionRoundState) {
  return state.questions.map((q) => ({ id: q.id, prompt: q.prompt, choices: q.choices }));
}

export function submitAnswer(
  state: CognitionRoundState,
  userId: string,
  questionId: string,
  choiceIndex: number,
): { ok: boolean; reason?: string } {
  if (Date.now() > state.deadline) return { ok: false, reason: "round-over" };
  const question = state.questions.find((q) => q.id === questionId);
  if (!question) return { ok: false, reason: "unknown-question" };

  const list = (state.answers[userId] ??= []);
  if (list.some((a) => a.questionId === questionId)) {
    return { ok: false, reason: "already-answered" };
  }
  list.push({ questionId, choiceIndex, msElapsed: Date.now() - state.startedAt });
  return { ok: true };
}

export function allAnswered(state: CognitionRoundState, match: Match): boolean {
  const total = state.questions.length;
  return match.players.every((p) => (state.answers[p.userId]?.length ?? 0) >= total);
}

/**
 * Score = correct answers, tie broken by total time (faster wins). We fold the
 * time into a fractional bonus so the single numeric score still orders players.
 */
export function resolveCognitionRound(state: CognitionRoundState, match: Match): RoundResult {
  const scores: Record<string, number> = {};
  for (const player of match.players) {
    const answers = state.answers[player.userId] ?? [];
    let correct = 0;
    let totalMs = 0;
    for (const ans of answers) {
      const q = state.questions.find((x) => x.id === ans.questionId);
      if (q && q.answerIndex === ans.choiceIndex) correct++;
      totalMs += ans.msElapsed;
    }
    // Faster completions get a small bonus in (0, 1) without ever overtaking a
    // correct answer. Lower time -> higher bonus.
    const speedBonus = totalMs > 0 ? Math.min(0.99, config.cognitionRoundMs / (totalMs + config.cognitionRoundMs)) : 0;
    scores[player.userId] = correct + speedBonus;
  }
  const [a, b] = match.players;
  const sa = scores[a.userId] ?? 0;
  const sb = scores[b.userId] ?? 0;
  let winnerId: string | null = null;
  if (sa > sb) winnerId = a.userId;
  else if (sb > sa) winnerId = b.userId;
  return { round: "cognition", scores, winnerId };
}
