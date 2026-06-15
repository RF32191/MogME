import { Router } from "express";
import { z } from "zod";
import { store } from "../store.js";

export const authRouter = Router();

const SignInBody = z.object({
  handle: z.string().min(2).max(24),
  // In production verify the Apple identity token and use its `sub`.
  appleSub: z.string().optional(),
});

/**
 * Minimal sign-in: creates (or returns) a user. Replace with Sign in with Apple
 * token verification before production. Returns the userId used for the WS auth.
 */
authRouter.post("/signin", (req, res) => {
  const parsed = SignInBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid-body", details: parsed.error.flatten() });
    return;
  }
  const user = store.createUser(parsed.data);
  res.json({ user });
});

const ConsentBody = z.object({ userId: z.string() });

/** Record biometric / image-sharing consent. Required before playing the face round. */
authRouter.post("/consent", (req, res) => {
  const parsed = ConsentBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid-body" });
    return;
  }
  const user = store.updateUser(parsed.data.userId, { consentedAt: Date.now() });
  if (!user) {
    res.status(404).json({ error: "unknown-user" });
    return;
  }
  res.json({ user });
});
