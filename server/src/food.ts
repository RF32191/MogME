export interface FoodRecord {
  id: string;
  name: string;
  brand?: string;
  calories: number;
  protein?: number;
  carbs?: number;
  fat?: number;
  fiber?: number;
  sugars?: number;
  sodium?: number;
  serving: string;
  source: string;
  analysis: string;
}

function num(v: unknown): number | undefined {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : undefined;
}

export function analysisLine(food: Omit<FoodRecord, "analysis">): string {
  const macros = [
    `${Math.round(food.calories)} kcal`,
    food.protein != null ? `${round1(food.protein)}g protein` : "",
    food.carbs != null ? `${round1(food.carbs)}g carbs` : "",
    food.fat != null ? `${round1(food.fat)}g fat` : "",
  ].filter(Boolean);
  return `${food.name} — ${macros.join(", ")} per ${food.serving} (${food.source}).`;
}

function round1(n: number): string {
  return (Math.round(n * 10) / 10).toString();
}

export async function searchFoods(query: string): Promise<FoodRecord[]> {
  const q = query.trim().slice(0, 80);
  if (q.length < 2) return [];
  const [off, usda] = await Promise.allSettled([openFoodFacts(q), usdaSearch(q)]);
  const rows = [
    ...(off.status === "fulfilled" ? off.value : []),
    ...(usda.status === "fulfilled" ? usda.value : []),
  ];
  const seen = new Set<string>();
  const out: FoodRecord[] = [];
  for (const row of rows) {
    const key = row.name.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ ...row, analysis: analysisLine(row) });
    if (out.length >= 20) break;
  }
  return out;
}

async function openFoodFacts(query: string): Promise<Omit<FoodRecord, "analysis">[]> {
  const url = new URL("https://world.openfoodfacts.org/cgi/search.pl");
  url.searchParams.set("search_terms", query);
  url.searchParams.set("search_simple", "1");
  url.searchParams.set("action", "process");
  url.searchParams.set("json", "1");
  url.searchParams.set("page_size", "15");
  const res = await fetch(url, { headers: { "User-Agent": "MogMe/1.4 (food lookup)" } });
  if (!res.ok) throw new Error("off-failed");
  const json = (await res.json()) as {
    products?: Array<{
      code?: string;
      product_name?: string;
      brands?: string;
      serving_size?: string;
      nutriments?: Record<string, number | string>;
    }>;
  };
  return (json.products ?? []).flatMap((p) => {
    const name = (p.product_name ?? "").trim();
    if (!name) return [];
    const n = p.nutriments ?? {};
    const kcal =
      num(n["energy-kcal_100g"]) ??
      num(n["energy-kcal_serving"]) ??
      (num(n.energy_100g) != null ? num(n.energy_100g)! / 4.184 : undefined);
    if (kcal == null || kcal <= 0 || kcal > 2500) return [];
    return [
      {
        id: p.code ?? name,
        name,
        brand: p.brands,
        calories: kcal,
        protein: num(n.proteins_100g),
        carbs: num(n.carbohydrates_100g),
        fat: num(n.fat_100g),
        fiber: num(n.fiber_100g),
        sugars: num(n.sugars_100g),
        sodium: num(n.sodium_100g) != null ? num(n.sodium_100g)! * 1000 : undefined,
        serving: p.serving_size || "100 g",
        source: "Open Food Facts",
      },
    ];
  });
}

async function usdaSearch(query: string): Promise<Omit<FoodRecord, "analysis">[]> {
  const key = process.env.USDA_API_KEY || "DEMO_KEY";
  const url = new URL("https://api.nal.usda.gov/fdc/v1/foods/search");
  url.searchParams.set("query", query);
  url.searchParams.set("pageSize", "10");
  url.searchParams.set("api_key", key);
  const res = await fetch(url);
  if (!res.ok) throw new Error("usda-failed");
  const json = (await res.json()) as {
    foods?: Array<{
      fdcId?: number;
      description?: string;
      brandName?: string;
      servingSize?: number;
      servingSizeUnit?: string;
      foodNutrients?: Array<{ nutrientName?: string; value?: number; unitName?: string }>;
    }>;
  };
  return (json.foods ?? []).flatMap((food) => {
    const name = (food.description ?? "").trim();
    if (!name) return [];
    const nutrients = food.foodNutrients ?? [];
    const pick = (names: string[]) =>
      num(
        nutrients.find((n) => names.some((want) => (n.nutrientName ?? "").toLowerCase().includes(want)))?.value,
      );
    const calories = pick(["energy"]) ?? pick(["calorie"]);
    if (calories == null || calories <= 0 || calories > 2500) return [];
    const serving =
      food.servingSize && food.servingSizeUnit
        ? `${food.servingSize} ${food.servingSizeUnit}`
        : "100 g";
    return [
      {
        id: String(food.fdcId ?? name),
        name,
        brand: food.brandName,
        calories,
        protein: pick(["protein"]),
        carbs: pick(["carbohydrate"]),
        fat: pick(["total lipid", "fat"]),
        fiber: pick(["fiber"]),
        sugars: pick(["sugars", "sugar"]),
        sodium: pick(["sodium"]),
        serving,
        source: "USDA FoodData Central",
      },
    ];
  });
}
