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
