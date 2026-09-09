import OpenAI from "openai";
import { config } from "./config.js";
import { moderateText } from "./moderation.js";
import {
  DailyTokenBudget,
  estimateTokensFromText,
  TOKEN_PRICES,
} from "./tokens.js";

let openai: OpenAI | null = null;
function getOpenAI(): OpenAI | null {
  if (!config.openaiApiKey) return null;
  if (!openai) openai = new OpenAI({ apiKey: config.openaiApiKey });
  return openai;
}

export const wingmanBudget = new DailyTokenBudget({
  dailyRequestCap: config.wingmanDailyRequestCap,
  dailyTokenCap: config.wingmanDailyTokenCap,
});

export type WingmanGoal = "evaluate" | "reply" | "strategy";

export interface PartnerMemoryInput {
  name?: string;
  notes?: string;
  style?: string;
  facts?: string[];
  doNots?: string[];
  lastTopics?: string[];
}

export interface WingmanTurn {
  role: "user" | "assistant";
  content: string;
}

export interface WingmanRequest {
  userKey: string;
  goal: WingmanGoal;
  text?: string;
  ocrText?: string;
  imageDataUrl?: string;
  memory?: PartnerMemoryInput;
  history?: WingmanTurn[];
}

export const WINGMAN_IMAGE_MAX_CHARS = 1_200_000;

export interface WingmanResult {
  ok: boolean;
  reason?: string;
  advice?: string;
  analysis?: string;
  transcript?: string;
  tone?: string;
  suggestedReplies?: string[];
  sawImage?: boolean;
  usage?: {
    requestsToday: number;
    requestsRemaining: number;
    tokensToday: number;
    tokensRemaining: number;
    estimatedCostUsdToday: number;
    thisRequest: { inputTokens: number; outputTokens: number; estimatedCostUsd: number };
  };
}

const GOAL_LINE: Record<WingmanGoal, string> = {
  evaluate:
    "Evaluate the conversation so far. Say what is working, what is falling flat, and the single best next move. Be concrete.",
  reply:
    "Draft 3 short, natural reply options the user could send next. Keep them in the user's voice: confident, specific, not cringe.",
  strategy:
    "Give a short texting strategy for the next few messages: pacing, tone, what to ask, and what to avoid with this person.",
};

function compactMemory(memory?: PartnerMemoryInput): string {
  if (!memory) return "No partner notes yet.";
  const facts = (memory.facts ?? []).slice(0, 8).map((f) => f.slice(0, 120));
  const avoid = (memory.doNots ?? []).slice(0, 6).map((f) => f.slice(0, 80));
  const topics = (memory.lastTopics ?? []).slice(0, 6).map((f) => f.slice(0, 80));
  return [
    memory.name ? `Name: ${memory.name.slice(0, 40)}` : "",
    memory.style ? `Their texting style: ${memory.style.slice(0, 80)}` : "",
    memory.notes ? `Notes: ${memory.notes.slice(0, 240)}` : "",
    facts.length ? `Facts: ${facts.join("; ")}` : "",
    avoid.length ? `Avoid: ${avoid.join("; ")}` : "",
    topics.length ? `Recent topics: ${topics.join("; ")}` : "",
  ]
    .filter(Boolean)
    .join("\n");
}

function systemPrompt(goal: WingmanGoal, memory?: PartnerMemoryInput): string {
  return [
    "You are MogMe Wingman, a concise dating/texting coach for adults (18+).",
    "The user is asking for help impressing someone they are already talking to.",
    "HARD RULES: strictly non-explicit, no harassment, no manipulation-as-deception, no insults about anyone's body. Tasteful charm only.",
    "Use the local partner memory as context. Do not invent facts they did not provide.",
    "If a chat screenshot is attached, transcribe the visible bubbles in your head and coach from those exact lines. Do not ignore the image. Do not spend the reply describing pixels.",
    GOAL_LINE[goal],
    "Respond ONLY as compact JSON: {\"transcript\": string (messages you can read), \"tone\": string, \"analysis\": string (<=3 short paragraphs), \"advice\": string, \"suggested_replies\": string[] (2-3 short texts)}.",
    "Partner memory:",
    compactMemory(memory),
  ].join("\n");
}

export type ImageCheck =
  | { status: "none" }
  | { status: "ok"; url: string }
  | { status: "error"; reason: string };

export function inspectImage(raw?: string): ImageCheck {
  if (!raw) return { status: "none" };
  const trimmed = raw.trim();
  if (!trimmed) return { status: "none" };
  if (!trimmed.startsWith("data:image/")) return { status: "error", reason: "image-invalid" };
  if (trimmed.length > WINGMAN_IMAGE_MAX_CHARS) return { status: "error", reason: "image-too-large" };
  return { status: "ok", url: trimmed };
}

export function projectWingmanInputTokens(req: WingmanRequest): number {
  const sys = systemPrompt(req.goal, req.memory);
  const text = (req.text ?? "").slice(0, 800);
  const history = (req.history ?? [])
    .slice(-6)
    .map((m) => `${m.role}: ${m.content.slice(0, 280)}`)
    .join("\n");
  const image = inspectImage(req.imageDataUrl).status === "ok" ? TOKEN_PRICES.lowDetailImageTokens : 0;
  return estimateTokensFromText(sys) + estimateTokensFromText(text) + estimateTokensFromText(history) + image;
}

export async function adviseWingman(req: WingmanRequest): Promise<WingmanResult> {
  const userKey = req.userKey.slice(0, 80) || "anon";
  const text = (req.text ?? "").trim().slice(0, 800);
  const ocrText = (req.ocrText ?? "").trim().slice(0, 4000);
  const imageCheck = inspectImage(req.imageDataUrl);
  if (imageCheck.status === "error") return { ok: false, reason: imageCheck.reason };
  const image = imageCheck.status === "ok" ? imageCheck.url : undefined;
  if (!text && !image && !ocrText) return { ok: false, reason: "empty" };

  if (text) {
    const mod = await moderateText(text);
    if (!mod.approved) return { ok: false, reason: `message-rejected:${mod.reason ?? "unknown"}` };
  }

  const projected = projectWingmanInputTokens({ ...req, imageDataUrl: image });
  const gate = wingmanBudget.canSpend(userKey, projected);
  if (!gate.ok) return { ok: false, reason: gate.reason };

  const client = getOpenAI();
  if (!client) {
    const fallback = heuristicWingman(req.goal, text || ocrText, Boolean(image || ocrText), ocrText);
    const usage = wingmanBudget.record(userKey, projected, estimateTokensFromText(fallback.advice));
    return withUsage(true, fallback.advice, fallback.suggestedReplies, projected, estimateTokensFromText(fallback.advice), usage, Boolean(image || ocrText), fallback);
  }

  const history = (req.history ?? []).slice(-6).map((m) => ({
    role: m.role,
    content: m.content.slice(0, 280),
  }));

  const userContent: OpenAI.Chat.ChatCompletionContentPart[] = [];
  userContent.push({
    type: "text",
    text: [
      text || "Analyze this conversation and tell me the next move.",
      ocrText ? `OCR from the screenshot:\n${ocrText}` : "",
      image ? "A chat screenshot is attached. Read the bubbles and analyze the thread." : "",
    ]
      .filter(Boolean)
      .join("\n\n"),
  });
  if (image) {
    userContent.push({
      type: "image_url",
      image_url: { url: image, detail: "low" },
    });
  }

  try {
    const completion = await client.chat.completions.create({
      model: config.wingmanModel,
      temperature: 0.7,
      max_tokens: config.wingmanMaxTokens,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt(req.goal, req.memory) },
        ...history.map((m) => ({ role: m.role, content: m.content })),
        { role: "user", content: userContent },
      ],
    });
    const raw = completion.choices[0]?.message?.content ?? "{}";
    const parsed = JSON.parse(raw) as {
      advice?: string;
      analysis?: string;
      transcript?: string;
      tone?: string;
      suggested_replies?: string[];
    };
    const advice = (parsed.analysis ?? parsed.advice ?? "").toString().trim().slice(0, 1400) || "Keep it specific and light — ask one real question about something they already mentioned.";
    const suggested = (parsed.suggested_replies ?? []).slice(0, 3).map((s) => s.toString().slice(0, 180));
    const outMod = await moderateText(`${advice}\n${suggested.join("\n")}`);
    const safeAdvice = outMod.approved ? advice : "Let's keep this respectful. Ask about their day and reference something they already shared.";
    const safeSuggested = outMod.approved ? suggested : ["How did that thing you mentioned go?", "That actually made me smile — tell me more."];
    const inTok = completion.usage?.prompt_tokens ?? projected;
    const outTok = completion.usage?.completion_tokens ?? estimateTokensFromText(safeAdvice);
    const usage = wingmanBudget.record(userKey, inTok, outTok);
    return withUsage(true, safeAdvice, safeSuggested, inTok, outTok, usage, Boolean(image || ocrText), {
      advice: safeAdvice,
      suggestedReplies: safeSuggested,
      analysis: safeAdvice,
      transcript: (parsed.transcript ?? ocrText).toString().slice(0, 1200),
      tone: (parsed.tone ?? "").toString().slice(0, 80),
    });
  } catch {
    const fallback = heuristicWingman(req.goal, text || ocrText, Boolean(image || ocrText), ocrText);
    const usage = wingmanBudget.record(userKey, projected, estimateTokensFromText(fallback.advice));
    return withUsage(true, fallback.advice, fallback.suggestedReplies, projected, estimateTokensFromText(fallback.advice), usage, Boolean(image || ocrText), fallback);
  }
}

function withUsage(
  ok: boolean,
  advice: string,
  suggestedReplies: string[],
  inputTokens: number,
  outputTokens: number,
  usage: ReturnType<DailyTokenBudget["record"]>,
  sawImage = false,
  extra?: { advice: string; suggestedReplies: string[]; analysis?: string; transcript?: string; tone?: string },
): WingmanResult {
  const remaining = {
    requests: Math.max(0, config.wingmanDailyRequestCap - usage.requests),
    tokens: Math.max(0, config.wingmanDailyTokenCap - usage.inputTokens - usage.outputTokens),
  };
  return {
    ok,
    advice,
    analysis: extra?.analysis ?? advice,
    transcript: extra?.transcript,
    tone: extra?.tone,
    suggestedReplies,
    sawImage,
    usage: {
      requestsToday: usage.requests,
      requestsRemaining: remaining.requests,
      tokensToday: usage.inputTokens + usage.outputTokens,
      tokensRemaining: remaining.tokens,
      estimatedCostUsdToday: Number(usage.estimatedCostUsd.toFixed(5)),
      thisRequest: {
        inputTokens,
        outputTokens,
        estimatedCostUsd: Number(((inputTokens / 1e6) * 0.15 + (outputTokens / 1e6) * 0.6).toFixed(5)),
      },
    },
  };
}

export function heuristicWingman(
  goal: WingmanGoal,
  text: string,
  sawImage = false,
  ocr = "",
): { advice: string; suggestedReplies: string[]; analysis: string; transcript: string; tone: string } {
  const transcript = ocr.slice(0, 800);
  const tone = /haha|lol|lmao|😂/i.test(ocr + text) ? "playful" : "neutral";
  const pack = (advice: string, suggestedReplies: string[]) => ({
    advice,
    suggestedReplies,
    analysis: transcript
      ? `${advice}\n\nI read this from the screenshot:\n${transcript}`
      : advice,
    transcript,
    tone,
  });
  if (sawImage && !text) {
    return pack(
      "I received the screenshot and billed this as a vision turn. The thread needs one specific callback to something they already said — then a question that is easy to answer.",
      [
        "Wait, go back to that thing you mentioned — what happened after?",
        "Okay that actually made me smile. Tell me the rest.",
      ],
    );
  }
  if (goal === "reply") {
    return pack("Mirror one specific detail they shared, then ask a follow-up that is easy to answer. Avoid stacking compliments.", [
      "Wait — that actually sounds fun. What made you pick that?",
      "Okay I need the short version and the real version.",
    ]);
  }
  if (goal === "strategy") {
    return pack("Slow the pace: one thoughtful text, then let them invest. Callback to a shared detail beats a generic pickup line.", [
      "You still owe me the rest of that story.",
      "Random, but that thing you said earlier stuck with me.",
    ]);
  }
  return pack(
    text
      ? "The energy is fine if you stay specific. Drop anything generic and ask one question that shows you actually read them."
      : "Upload the chat or paste the last few lines so I can judge the actual rhythm.",
    ["That’s fair — what would a good next step look like for you?", "I like how you put that."],
  );
}
