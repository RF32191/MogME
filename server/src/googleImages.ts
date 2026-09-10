const GENERIC = new Set([
  "food",
  "meal",
  "dish",
  "plate",
  "cuisine",
  "recipe",
  "lunch",
  "dinner",
  "breakfast",
  "snack",
  "ingredient",
  "produce",
  "vegetable",
  "fruit",
  "meat",
  "table",
  "bowl",
  "restaurant",
]);

export interface GoogleImageMatch {
  title: string;
  imageUrl: string;
  pageUrl?: string;
  thumbUrl?: string;
}

export interface VisionWebGuess {
  bestGuess: string;
  webEntities: string[];
  similarImages: GoogleImageMatch[];
}

export interface FoodNamePick {
  name: string;
  description: string;
  source: "google-vision" | "google-images" | "label" | "ocr" | "unknown";
}

export function isFoodish(raw: string): boolean {
  const text = raw.trim().toLowerCase();
  if (text.length < 3 || text.length > 80) return false;
  if (GENERIC.has(text)) return false;
  if (/https?:|www\./.test(text)) return false;
  return /[a-z]/.test(text);
}

export function cleanFoodName(raw: string): string {
  return raw
    .replace(/\s+[|\-–—].+$/, "")
    .replace(/\s+\(\d{4}\).*$/, "")
    .replace(/\b(recipe|recipes|homemade|easy|best|how to make)\b/gi, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 64);
}

export function pickFoodName(input: {
  bestGuess?: string;
  webEntities?: string[];
  imageTitles?: string[];
  ocr?: string;
  labels?: string[];
}): FoodNamePick {
  const vision = cleanFoodName(input.bestGuess ?? "");
  if (isFoodish(vision)) {
    return {
      name: vision,
      description: `Looks like ${vision}. Matched this photo against Google Images.`,
      source: "google-vision",
    };
  }

  const fromImages = (input.imageTitles ?? [])
    .map(cleanFoodName)
    .find((title) => isFoodish(title));
  if (fromImages) {
    return {
      name: fromImages,
      description: `Looks like ${fromImages}. Named from similar Google Images.`,
      source: "google-images",
    };
  }

  const entity = (input.webEntities ?? []).map(cleanFoodName).find((name) => isFoodish(name));
  if (entity) {
    return {
      name: entity,
      description: `Looks like ${entity}. Google Images web match.`,
      source: "google-vision",
    };
  }

  const label = (input.labels ?? []).map(cleanFoodName).find((name) => isFoodish(name));
  if (label) {
    return {
      name: label,
      description: `Looks like ${label}. On-device label — confirm or search Google Images again.`,
      source: "label",
    };
  }

  const ocrLine = (input.ocr ?? "")
    .split(/\n/)
    .map((line) => cleanFoodName(line))
    .find((line) => isFoodish(line) && !/nutrition|calories|ingredients|serving/i.test(line));
  if (ocrLine) {
    return {
      name: ocrLine,
      description: `Label text reads “${ocrLine}”.`,
      source: "ocr",
    };
  }

  return {
    name: "",
    description: "Could not identify this food from Google Images yet. Type the name.",
    source: "unknown",
  };
}

export function parseVisionWeb(json: unknown): VisionWebGuess {
  const root = json as {
    responses?: Array<{
      webDetection?: {
        bestGuessLabels?: Array<{ label?: string }>;
        webEntities?: Array<{ description?: string; score?: number }>;
        visuallySimilarImages?: Array<{ url?: string }>;
        fullMatchingImages?: Array<{ url?: string }>;
        pagesWithMatchingImages?: Array<{ url?: string; pageTitle?: string }>;
      };
      labelAnnotations?: Array<{ description?: string; score?: number }>;
    }>;
  };
  const web = root.responses?.[0]?.webDetection;
  const labels = root.responses?.[0]?.labelAnnotations ?? [];
  const bestGuess = (web?.bestGuessLabels ?? []).map((row) => row.label ?? "").find(isFoodish) ?? "";
  const webEntities = [
    ...(web?.webEntities ?? [])
      .slice()
      .sort((a, b) => (b.score ?? 0) - (a.score ?? 0))
      .map((row) => row.description ?? ""),
    ...labels.map((row) => row.description ?? ""),
  ].filter(isFoodish);
  const similarImages: GoogleImageMatch[] = [
    ...(web?.pagesWithMatchingImages ?? []).map((page) => ({
      title: cleanFoodName(page.pageTitle ?? bestGuess),
      imageUrl: page.url ?? "",
      pageUrl: page.url,
    })),
    ...(web?.fullMatchingImages ?? []).map((img) => ({
      title: bestGuess,
      imageUrl: img.url ?? "",
    })),
    ...(web?.visuallySimilarImages ?? []).map((img) => ({
      title: bestGuess,
      imageUrl: img.url ?? "",
    })),
  ].filter((img) => img.imageUrl.startsWith("http")).slice(0, 8);
  return { bestGuess, webEntities, similarImages };
}

export function parseGoogleImageSearch(json: unknown): GoogleImageMatch[] {
  const root = json as {
    items?: Array<{
      title?: string;
      link?: string;
      image?: { thumbnailLink?: string; contextLink?: string };
    }>;
  };
  return (root.items ?? [])
    .map((item) => ({
      title: cleanFoodName(item.title ?? ""),
      imageUrl: item.link ?? "",
      pageUrl: item.image?.contextLink,
      thumbUrl: item.image?.thumbnailLink,
    }))
    .filter((item) => item.imageUrl.startsWith("http"))
    .slice(0, 8);
}

function dataUrlToBase64(dataUrl: string): string {
  const idx = dataUrl.indexOf(",");
  return idx >= 0 ? dataUrl.slice(idx + 1) : dataUrl;
}

export async function googleVisionWebDetect(
  imageDataUrl: string,
  apiKey: string,
): Promise<VisionWebGuess> {
  if (!apiKey) return { bestGuess: "", webEntities: [], similarImages: [] };
  const res = await fetch(`https://vision.googleapis.com/v1/images:annotate?key=${encodeURIComponent(apiKey)}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      requests: [
        {
          image: { content: dataUrlToBase64(imageDataUrl) },
          features: [
            { type: "WEB_DETECTION", maxResults: 10 },
            { type: "LABEL_DETECTION", maxResults: 8 },
          ],
        },
      ],
    }),
  });
  if (!res.ok) throw new Error("google-vision-failed");
  return parseVisionWeb(await res.json());
}

export async function googleImageSearch(
  query: string,
  apiKey: string,
  cx: string,
): Promise<GoogleImageMatch[]> {
  const q = query.trim().slice(0, 80);
  if (!q || !apiKey || !cx) return [];
  const url = new URL("https://www.googleapis.com/customsearch/v1");
  url.searchParams.set("key", apiKey);
  url.searchParams.set("cx", cx);
  url.searchParams.set("q", q);
  url.searchParams.set("searchType", "image");
  url.searchParams.set("num", "6");
  url.searchParams.set("safe", "active");
  const res = await fetch(url);
  if (!res.ok) throw new Error("google-images-failed");
  return parseGoogleImageSearch(await res.json());
}
