import assert from "node:assert/strict";
import test from "node:test";
import { analysisLine } from "./food.js";

test("food analysis names the item and macros", () => {
  const line = analysisLine({
    id: "1",
    name: "Chicken breast, cooked",
    calories: 165,
    protein: 31,
    carbs: 0,
    fat: 3.6,
    serving: "100 g",
    source: "USDA FoodData Central",
  });
  assert.match(line, /Chicken breast/);
  assert.match(line, /165 kcal/);
  assert.match(line, /protein/);
  assert.match(line, /USDA/);
});
