import assert from "node:assert/strict";
import test from "node:test";
import { analysisLine } from "./food.js";
import { pickFoodName, parseGoogleImageSearch, parseVisionWeb, isFoodish } from "./googleImages.js";

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

test("Google Images / Vision guess becomes the food name", () => {
  const pick = pickFoodName({
    bestGuess: "chicken rice bowl",
    webEntities: ["Food", "Rice"],
    imageTitles: ["Easy Chicken Rice Bowl Recipe | Dinner"],
  });
  assert.equal(pick.name.toLowerCase(), "chicken rice bowl");
  assert.match(pick.description, /Google Images/i);
  assert.equal(pick.source, "google-vision");
});

test("Google Images titles identify food when Vision has no guess", () => {
  const pick = pickFoodName({
    imageTitles: ["Salmon avocado poke bowl - recipe"],
    labels: ["food", "plate"],
  });
  assert.match(pick.name.toLowerCase(), /salmon avocado poke bowl/);
  assert.equal(pick.source, "google-images");
});

test("generic plate words are not treated as a food name", () => {
  assert.equal(isFoodish("food"), false);
  assert.equal(isFoodish("plate"), false);
  assert.equal(isFoodish("chicken tikka"), true);
});

test("Vision web payload yields a best guess and similar images", () => {
  const parsed = parseVisionWeb({
    responses: [
      {
        webDetection: {
          bestGuessLabels: [{ label: "avocado toast" }],
          webEntities: [{ description: "Avocado toast", score: 1.4 }],
          visuallySimilarImages: [{ url: "https://example.com/toast.jpg" }],
        },
      },
    ],
  });
  assert.equal(parsed.bestGuess, "avocado toast");
  assert.equal(parsed.similarImages[0]?.imageUrl, "https://example.com/toast.jpg");
});

test("Google Image Search items keep title and thumbnail", () => {
  const items = parseGoogleImageSearch({
    items: [
      {
        title: "Avocado Toast Recipe",
        link: "https://example.com/full.jpg",
        image: { thumbnailLink: "https://example.com/thumb.jpg", contextLink: "https://example.com" },
      },
    ],
  });
  assert.equal(items[0]?.thumbUrl, "https://example.com/thumb.jpg");
  assert.match(items[0]?.title ?? "", /avocado toast/i);
});
