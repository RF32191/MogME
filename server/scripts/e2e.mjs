// Quick end-to-end smoke test: two players run a full match (face -> cognition -> rizz).
import WebSocket from "ws";

const BASE = "http://localhost:8787";
const WS = "ws://localhost:8787/ws";

async function signin(handle) {
  const res = await fetch(`${BASE}/auth/signin`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ handle }),
  });
  const { user } = await res.json();
  return user;
}

function play(user, label) {
  return new Promise((resolve) => {
    const ws = new WebSocket(WS);
    const log = (...a) => console.log(`[${label}]`, ...a);
    let questions = [];

    ws.on("open", () => ws.send(JSON.stringify({ type: "auth", userId: user.id })));
    ws.on("message", (raw) => {
      const m = JSON.parse(raw.toString());
      switch (m.type) {
        case "auth.ok":
          ws.send(JSON.stringify({ type: "queue.join" }));
          break;
        case "match.found":
          log("matched vs", m.opponent.handle, "rounds:", m.rounds.join(","));
          break;
        case "round.start":
          log("round.start:", m.round);
          if (m.round === "face") {
            const score = 5 + Math.random() * 4;
            ws.send(JSON.stringify({ type: "face.submit", score, distortedImage: "data:image/png;base64,STUB" }));
            log("submitted face score", score.toFixed(2));
          } else if (m.round === "cognition") {
            questions = m.questions;
            questions.forEach((q, i) => {
              setTimeout(() => {
                ws.send(JSON.stringify({ type: "cognition.answer", questionId: q.id, choiceIndex: Math.floor(Math.random() * q.choices.length) }));
              }, i * 50);
            });
          } else if (m.round === "rizz") {
            let turn = 0;
            const lines = ["Hey, you have great taste in films — what's your all-time favorite?", "Haha that's such a good pick. I'd totally watch that with you.", "Okay you're funnier than you let on. Coffee sometime?"];
            const sendLine = () => {
              if (turn < lines.length) ws.send(JSON.stringify({ type: "rizz.message", text: lines[turn++] }));
            };
            sendLine();
            ws._rizz = sendLine;
          }
          break;
        case "face.opponent":
          log("received opponent distorted image (len)", m.image?.length);
          break;
        case "rizz.reply":
          log("rizz reply:", m.reply, "| affection:", m.affection);
          if (ws._rizz) setTimeout(ws._rizz, 100);
          break;
        case "round.result":
          log("round.result:", m.result.round, "winner:", m.result.winnerId ?? "tie");
          break;
        case "match.complete":
          log("MATCH COMPLETE. winner:", m.final.winnerId ?? "tie", "elo:", JSON.stringify(m.final.eloChange));
          ws.close();
          resolve();
          break;
        case "error":
          log("error:", m.reason);
          break;
      }
    });
  });
}

const a = await signin("alice");
const b = await signin("bob");
await Promise.all([play(a, "alice"), play(b, "bob")]);
console.log("\nE2E complete.");
process.exit(0);
