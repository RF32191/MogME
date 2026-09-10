import { config } from "./config.js";

/**
 * Conservative token + dollar estimates for Railway-hosted OpenAI calls.
 * Prices are gpt-4o-mini list rates (USD / 1M tokens). Vision "low" detail is 85 tokens.
 */

export const TOKEN_PRICES = {
  inputPerMillion: 0.15,
  outputPerMillion: 0.6,
  lowDetailImageTokens: 85,
} as const;

export function estimateTokensFromText(text: string): number {
  const trimmed = text.trim();
  if (!trimmed) return 0;
  // ~4 chars/token is the usual cheap estimate for English + JSON.
  return Math.max(1, Math.ceil(trimmed.length / 4));
}

export function estimateCostUsd(inputTokens: number, outputTokens: number): number {
  return (
    (inputTokens / 1_000_000) * TOKEN_PRICES.inputPerMillion +
    (outputTokens / 1_000_000) * TOKEN_PRICES.outputPerMillion
  );
}

export interface TokenBudgetConfig {
  dailyRequestCap: number;
  dailyTokenCap: number;
}

export interface TokenUsage {
  requests: number;
  inputTokens: number;
  outputTokens: number;
  estimatedCostUsd: number;
  dayKey: string;
}

function utcDayKey(now = new Date()): string {
  return now.toISOString().slice(0, 10);
}

const purchasedTokens = new Map<string, number>();

export function creditPurchasedTokens(userKey: string, tokens: number): number {
  const key = userKey.slice(0, 80) || "anon";
  const next = Math.max(0, (purchasedTokens.get(key) ?? 0) + Math.max(0, Math.floor(tokens)));
  purchasedTokens.set(key, next);
  return next;
}

export function purchasedTokenBalance(userKey: string): number {
  return purchasedTokens.get(userKey.slice(0, 80) || "anon") ?? 0;
}

export class DailyTokenBudget {
  private byUser = new Map<string, TokenUsage>();

  constructor(private readonly limits: TokenBudgetConfig) {}

  snapshot(userKey: string, now = new Date()): TokenUsage {
    const day = utcDayKey(now);
    const existing = this.byUser.get(userKey);
    if (!existing || existing.dayKey !== day) {
      const fresh: TokenUsage = {
        requests: 0,
        inputTokens: 0,
        outputTokens: 0,
        estimatedCostUsd: 0,
        dayKey: day,
      };
      this.byUser.set(userKey, fresh);
      return { ...fresh };
    }
    return { ...existing };
  }

  remaining(userKey: string, now = new Date()): { requests: number; tokens: number } {
    const used = this.snapshot(userKey, now);
    const extra = purchasedTokenBalance(userKey);
    const freeLeft = Math.max(0, this.limits.dailyRequestCap - used.requests);
    return {
      requests: freeLeft,
      tokens: freeLeft + extra,
    };
  }

  canSpend(userKey: string, _projectedInput = 1, now = new Date()): { ok: true } | { ok: false; reason: string } {
    const used = this.snapshot(userKey, now);
    const extra = purchasedTokenBalance(userKey);
    const freeLeft = Math.max(0, this.limits.dailyRequestCap - used.requests);
    if (freeLeft + extra < 1) {
      return { ok: false, reason: extra > 0 ? "daily-token-cap" : "daily-request-cap" };
    }
    return { ok: true };
  }

  record(userKey: string, inputTokens: number, outputTokens: number, now = new Date()): TokenUsage {
    const current = this.snapshot(userKey, now);
    current.requests += 1;
    current.inputTokens += inputTokens;
    current.outputTokens += outputTokens;
    current.estimatedCostUsd += estimateCostUsd(inputTokens, outputTokens);
    if (current.requests > this.limits.dailyRequestCap) {
      const extra = purchasedTokenBalance(userKey);
      if (extra > 0) purchasedTokens.set(userKey, extra - 1);
    }
    this.byUser.set(userKey, current);
    return { ...current };
  }
}

/** One shared pool for wingman, companion, rizz trainer, and mog-off rizz. */
export const aiBudget = new DailyTokenBudget({
  dailyRequestCap: config.aiDailyRequestCap,
  dailyTokenCap: config.aiDailyTokenCap,
});

export interface AIUsagePayload {
  requestsToday: number;
  requestsRemaining: number;
  tokensToday: number;
  tokensRemaining: number;
  purchasedTokens?: number;
  dailyTokenCap: number;
  dailyRequestCap: number;
  estimatedCostUsdToday: number;
  thisRequest?: { inputTokens: number; outputTokens: number; estimatedCostUsd: number };
}

export function aiUsagePayload(
  userKey: string,
  thisRequest?: { inputTokens: number; outputTokens: number },
): AIUsagePayload {
  const used = aiBudget.snapshot(userKey);
  const remaining = aiBudget.remaining(userKey);
  return {
    requestsToday: used.requests,
    requestsRemaining: remaining.requests,
    tokensToday: used.requests,
    tokensRemaining: remaining.tokens,
    purchasedTokens: purchasedTokenBalance(userKey),
    dailyTokenCap: config.aiDailyTokenCap,
    dailyRequestCap: config.aiDailyRequestCap,
    estimatedCostUsdToday: Number(used.estimatedCostUsd.toFixed(5)),
    thisRequest: thisRequest
      ? {
          inputTokens: thisRequest.inputTokens,
          outputTokens: thisRequest.outputTokens,
          estimatedCostUsd: Number(estimateCostUsd(thisRequest.inputTokens, thisRequest.outputTokens).toFixed(5)),
        }
      : undefined,
  };
}
