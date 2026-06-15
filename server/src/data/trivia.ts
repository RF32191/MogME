import type { CognitionQuestion } from "../types.js";

/**
 * Starter cognition/trivia bank. In production, move this to the DB, expand it
 * heavily, and tag questions by category/difficulty so rounds can be balanced.
 * answerIndex is never serialized to clients (see cognition round serializer).
 */
export const TRIVIA_BANK: Omit<CognitionQuestion, "id">[] = [
  {
    prompt: "Which number comes next: 2, 6, 12, 20, 30, ?",
    choices: ["36", "42", "40", "44"],
    answerIndex: 1, // differences 4,6,8,10,12 -> 42
  },
  {
    prompt: "If FACE is to 6135, then what is the code for CAFE?",
    choices: ["3165", "3615", "1635", "3156"],
    answerIndex: 0, // C=3 A=1 F=6 E=5
  },
  {
    prompt: "A bat and a ball cost $1.10. The bat costs $1 more than the ball. How much is the ball?",
    choices: ["$0.10", "$0.05", "$0.01", "$0.15"],
    answerIndex: 1,
  },
  {
    prompt: "Which word is the odd one out?",
    choices: ["Apple", "Banana", "Carrot", "Mango"],
    answerIndex: 2, // carrot is a vegetable
  },
  {
    prompt: "Complete the analogy: Finger is to Hand as Leaf is to ___",
    choices: ["Tree", "Branch", "Root", "Flower"],
    answerIndex: 1,
  },
  {
    prompt: "What is 15% of 60?",
    choices: ["6", "9", "12", "15"],
    answerIndex: 1,
  },
  {
    prompt: "Rearrange LISTEN to make another common word:",
    choices: ["TINSEL", "SILENT", "ENLIST", "All of these"],
    answerIndex: 3,
  },
  {
    prompt: "Which shape has the most sides?",
    choices: ["Hexagon", "Pentagon", "Octagon", "Heptagon"],
    answerIndex: 2,
  },
  {
    prompt: "If you rearrange the letters 'CIFAIPC' you get the name of a:",
    choices: ["City", "Animal", "Ocean", "River"],
    answerIndex: 2, // PACIFIC
  },
  {
    prompt: "Next in series: J, F, M, A, M, ?",
    choices: ["J", "S", "O", "N"],
    answerIndex: 0, // months -> June
  },
  {
    prompt: "Two trains 100 miles apart head toward each other at 50 mph each. When do they meet?",
    choices: ["30 min", "1 hour", "1.5 hours", "2 hours"],
    answerIndex: 1,
  },
  {
    prompt: "Which is heaviest?",
    choices: ["1 kg of feathers", "1 kg of steel", "They weigh the same", "Depends on volume"],
    answerIndex: 2,
  },
];
