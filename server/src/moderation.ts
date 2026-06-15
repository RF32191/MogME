import { config } from "./config.js";
import OpenAI from "openai";

/**
 * Moderation hooks for user-generated content.
 *
 * - Text moderation guards AI-rizz chat messages.
 * - Image moderation MUST run on every uploaded distorted face image BEFORE it is
 *   relayed to the opponent. Even though the image is distorted, you are storing
 *   and transmitting a face derivative, so screen it.
 *
 * The "stub" provider approves everything and exists so the server runs locally
 * without external keys. Wire a real provider (OpenAI omni-moderation, Hive,
 * Sightengine) before any production traffic. CSAM scanning (e.g. PhotoDNA/Safer)
 * is a separate, legally required pipeline and is not implemented here.
 */

export type Verdict = { approved: boolean; reason?: string };

let openai: OpenAI | null = null;
function getOpenAI(): OpenAI | null {
  if (!config.openaiApiKey) return null;
  if (!openai) openai = new OpenAI({ apiKey: config.openaiApiKey });
  return openai;
}

export async function moderateText(text: string): Promise<Verdict> {
  if (!config.moderationEnabled) return { approved: true };

  if (config.moderationProvider === "openai") {
    const client = getOpenAI();
    if (!client) return { approved: true, reason: "no-openai-key" };
    try {
      const res = await client.moderations.create({
        model: "omni-moderation-latest",
        input: text,
      });
      const result = res.results[0];
      if (result?.flagged) {
        const cats = Object.entries(result.categories ?? {})
          .filter(([, v]) => v)
          .map(([k]) => k);
        return { approved: false, reason: cats.join(",") || "flagged" };
      }
      return { approved: true };
    } catch (err) {
      // Fail closed on moderation errors for user-to-user content.
      return { approved: false, reason: "moderation-error" };
    }
  }

  // stub
  return { approved: true };
}

export async function moderateImage(_dataUrlOrKey: string): Promise<Verdict> {
  if (!config.moderationEnabled) return { approved: true };
  // TODO: wire Hive/Sightengine/Rekognition for nudity/abuse + a CSAM pipeline.
  // Until then, fail closed when moderation is enabled but no provider is wired.
  if (config.moderationProvider === "stub") {
    return { approved: false, reason: "image-moderation-not-configured" };
  }
  return { approved: true };
}
