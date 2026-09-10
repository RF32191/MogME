import assert from "node:assert/strict";
import test from "node:test";
import { DailyTokenBudget, estimateCostUsd, estimateTokensFromText } from "./tokens.js";
import { heuristicWingman, inspectImage, projectWingmanInputTokens } from "./wingman.js";

test("token estimate is cheap and non-zero", () => {
  const tokens = estimateTokensFromText("hello wingman");
  assert.ok(tokens >= 1 && tokens <= 20);
  assert.ok(estimateCostUsd(800, 280) < 0.001);
});

test("daily budget blocks after the request cap", () => {
  const budget = new DailyTokenBudget({ dailyRequestCap: 2, dailyTokenCap: 10_000 });
  assert.equal(budget.canSpend("u1", 100).ok, true);
  budget.record("u1", 100, 50);
  budget.record("u1", 100, 50);
  const blocked = budget.canSpend("u1", 100);
  assert.equal(blocked.ok, false);
  if (!blocked.ok) assert.equal(blocked.reason, "daily-request-cap");
});

test("purchased AI tokens extend the wallet past the daily cap", async () => {
  const { creditPurchasedTokens, purchasedTokenBalance } = await import("./tokens.js");
  const key = `buy-${Date.now()}`;
  assert.equal(purchasedTokenBalance(key), 0);
  assert.equal(creditPurchasedTokens(key, 100), 100);
  const budget = new DailyTokenBudget({ dailyRequestCap: 5, dailyTokenCap: 5 });
  for (let i = 0; i < 5; i++) budget.record(key, 10, 10);
  assert.equal(purchasedTokenBalance(key), 100);
  assert.equal(budget.canSpend(key, 1).ok, true);
  budget.record(key, 10, 10);
  assert.equal(purchasedTokenBalance(key), 99);
  assert.equal(budget.remaining(key).tokens, 99);
});

test("one purchased token is one extra AI message", async () => {
  const { creditPurchasedTokens, purchasedTokenBalance } = await import("./tokens.js");
  const key = `one-${Date.now()}`;
  creditPurchasedTokens(key, 2);
  const budget = new DailyTokenBudget({ dailyRequestCap: 1, dailyTokenCap: 1 });
  budget.record(key, 10, 10);
  budget.record(key, 10, 10);
  assert.equal(purchasedTokenBalance(key), 1);
  budget.record(key, 10, 10);
  assert.equal(purchasedTokenBalance(key), 0);
  assert.equal(budget.canSpend(key).ok, false);
});

test("wingman projection stays small without an image", () => {
  const tokens = projectWingmanInputTokens({
    userKey: "u",
    goal: "evaluate",
    text: "she left me on read after I asked about her weekend",
    memory: { name: "Alex", facts: ["likes climbing"] },
  });
  assert.ok(tokens < 1200);
});

test("heuristic wingman always returns usable copy", () => {
  const reply = heuristicWingman("reply", "hey");
  assert.ok(reply.advice.length > 10);
  assert.ok(reply.suggestedReplies.length >= 2);
});

test("chat screenshots are accepted and add vision tokens", () => {
  const url = `data:image/jpeg;base64,${"a".repeat(80)}`;
  assert.equal(inspectImage(url).status, "ok");
  assert.equal(inspectImage("not-an-image").status, "error");
  const withImage = projectWingmanInputTokens({
    userKey: "u",
    goal: "evaluate",
    text: "read this",
    imageDataUrl: url,
  });
  const without = projectWingmanInputTokens({
    userKey: "u",
    goal: "evaluate",
    text: "read this",
  });
  assert.ok(withImage - without === 85);
});

test("screenshot-only heuristic still bills as a vision turn", () => {
  const shot = heuristicWingman("evaluate", "", true);
  assert.match(shot.advice, /screenshot/i);
});

test("shared AI budget is not unlimited across features", async () => {
  const { companionReply } = await import("./companion.js");
  const { practiceTurn, startPractice } = await import("./practice.js");
  const key = `cap-${Date.now()}`;
  const { aiBudget } = await import("./tokens.js");
  for (let i = 0; i < 15; i++) {
    aiBudget.record(key, 10, 10);
  }
  const companion = await companionReply(
    { name: "Avery", age: 24, tone: "friend" },
    [],
    "hey",
    key,
  );
  assert.equal(companion.ok, false);
  assert.equal(companion.reason, "daily-request-cap");

  const session = startPractice("open", "easy");
  const rizz = await practiceTurn(session, "hey there, how is your week going?", key);
  assert.equal(rizz.ok, false);
  assert.equal(rizz.reason, "daily-request-cap");

  const { rizzTurn, initRizzRound } = await import("./rounds/rizz.js");
  const mogOff = await rizzTurn(initRizzRound(), key, "hey there, how is your week going?");
  assert.equal(mogOff.ok, false);
  assert.equal(mogOff.reason, "daily-request-cap");
});
