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

  // ── Number sequences ──────────────────────────────────────────────
  {
    prompt: "Which number comes next: 1, 1, 2, 3, 5, 8, ?",
    choices: ["11", "12", "13", "15"],
    answerIndex: 2, // Fibonacci
  },
  {
    prompt: "Which number comes next: 3, 9, 27, 81, ?",
    choices: ["162", "243", "216", "324"],
    answerIndex: 1, // ×3
  },
  {
    prompt: "Which number comes next: 1, 4, 9, 16, 25, ?",
    choices: ["30", "35", "36", "49"],
    answerIndex: 2, // squares
  },
  {
    prompt: "Which number comes next: 1, 2, 4, 7, 11, ?",
    choices: ["14", "15", "16", "18"],
    answerIndex: 2, // +1,+2,+3,+4,+5
  },
  {
    prompt: "Which number comes next: 100, 96, 89, 79, ?",
    choices: ["66", "69", "64", "70"],
    answerIndex: 0, // -4,-7,-10,-13
  },
  {
    prompt: "Next in the series: A, C, E, G, ?",
    choices: ["H", "I", "J", "K"],
    answerIndex: 1, // skip one
  },
  {
    prompt: "Next in the series: Z, X, V, T, ?",
    choices: ["S", "R", "Q", "U"],
    answerIndex: 1, // back two
  },

  // ── Mental math ───────────────────────────────────────────────────
  {
    prompt: "What is 25% of 200?",
    choices: ["40", "50", "60", "75"],
    answerIndex: 1,
  },
  {
    prompt: "What is 12 × 12?",
    choices: ["121", "132", "144", "156"],
    answerIndex: 2,
  },
  {
    prompt: "A $40 shirt is 25% off. What's the final price?",
    choices: ["$30", "$32", "$28", "$35"],
    answerIndex: 0,
  },
  {
    prompt: "What is 2 to the power of 10?",
    choices: ["512", "1000", "1024", "2048"],
    answerIndex: 2,
  },
  {
    prompt: "What is the square root of 169?",
    choices: ["11", "12", "13", "14"],
    answerIndex: 2,
  },
  {
    prompt: "If 3x = 21, what is x?",
    choices: ["6", "7", "8", "9"],
    answerIndex: 1,
  },
  {
    prompt: "What is the average of 10, 20, and 30?",
    choices: ["15", "20", "25", "30"],
    answerIndex: 1,
  },
  {
    prompt: "What is 1/2 + 1/4?",
    choices: ["3/4", "2/6", "1/3", "5/8"],
    answerIndex: 0,
  },

  // ── Words & anagrams ──────────────────────────────────────────────
  {
    prompt: "Unscramble these letters into a word: T A E H R",
    choices: ["HEART", "HOUSE", "TEACH", "THREW"],
    answerIndex: 0,
  },
  {
    prompt: "Which word is spelled correctly?",
    choices: ["Recieve", "Receive", "Receeve", "Receve"],
    answerIndex: 1,
  },
  {
    prompt: "Which of these is a palindrome?",
    choices: ["Level", "World", "Happy", "Stone"],
    answerIndex: 0,
  },
  {
    prompt: "What is the opposite of 'expand'?",
    choices: ["Grow", "Contract", "Stretch", "Enlarge"],
    answerIndex: 1,
  },
  {
    prompt: "Which word is a synonym for 'happy'?",
    choices: ["Sad", "Joyful", "Angry", "Tired"],
    answerIndex: 1,
  },

  // ── Odd one out ───────────────────────────────────────────────────
  {
    prompt: "Which is the odd one out?",
    choices: ["Mercury", "Venus", "Earth", "Moon"],
    answerIndex: 3, // the Moon isn't a planet
  },
  {
    prompt: "Which is the odd one out?",
    choices: ["Triangle", "Square", "Circle", "Pentagon"],
    answerIndex: 2, // no straight edges/corners
  },
  {
    prompt: "Which is the odd one out?",
    choices: ["Cat", "Dog", "Lion", "Apple"],
    answerIndex: 3,
  },

  // ── Analogies ─────────────────────────────────────────────────────
  {
    prompt: "Complete the analogy: Bird is to Fly as Fish is to ___",
    choices: ["Walk", "Swim", "Run", "Jump"],
    answerIndex: 1,
  },
  {
    prompt: "Complete the analogy: Author is to Book as Composer is to ___",
    choices: ["Painting", "Symphony", "Poem", "Statue"],
    answerIndex: 1,
  },
  {
    prompt: "Complete the analogy: Puppy is to Dog as Kitten is to ___",
    choices: ["Cat", "Cow", "Horse", "Fox"],
    answerIndex: 0,
  },
  {
    prompt: "Complete the analogy: Day is to Night as Black is to ___",
    choices: ["Dark", "White", "Gray", "Blue"],
    answerIndex: 1,
  },

  // ── Lateral thinking ──────────────────────────────────────────────
  {
    prompt: "A farmer has 17 sheep. All but 9 run away. How many are left?",
    choices: ["8", "9", "17", "0"],
    answerIndex: 1,
  },
  {
    prompt: "How many months have at least 28 days?",
    choices: ["1", "2", "11", "12"],
    answerIndex: 3,
  },
  {
    prompt: "There are 3 apples and you take 2. How many do you have?",
    choices: ["1", "2", "3", "5"],
    answerIndex: 1,
  },
  {
    prompt: "Mary's father has 5 daughters: Nana, Nene, Nini, Nono, and ___?",
    choices: ["Nunu", "Mary", "Nina", "Nadia"],
    answerIndex: 1,
  },
  {
    prompt: "What comes once in a minute, twice in a moment, but never in a thousand years?",
    choices: ["The letter M", "Time", "A heartbeat", "Nothing"],
    answerIndex: 0,
  },

  // ── Geometry & general knowledge ──────────────────────────────────
  {
    prompt: "How many degrees are in a right angle?",
    choices: ["45", "90", "180", "360"],
    answerIndex: 1,
  },
  {
    prompt: "How many faces does a cube have?",
    choices: ["4", "6", "8", "12"],
    answerIndex: 1,
  },
  {
    prompt: "The hands of a clock at 3:00 form what angle?",
    choices: ["45°", "60°", "90°", "120°"],
    answerIndex: 2,
  },
  {
    prompt: "How many continents are there on Earth?",
    choices: ["5", "6", "7", "8"],
    answerIndex: 2,
  },
  {
    prompt: "What is the largest planet in our solar system?",
    choices: ["Saturn", "Jupiter", "Neptune", "Earth"],
    answerIndex: 1,
  },
  {
    prompt: "How many minutes are in 2.5 hours?",
    choices: ["120", "150", "160", "180"],
    answerIndex: 1,
  },
  {
    prompt: "Which of these numbers is prime?",
    choices: ["9", "15", "17", "21"],
    answerIndex: 2,
  },
  {
    prompt: "What is the next prime number after 7?",
    choices: ["9", "10", "11", "13"],
    answerIndex: 2,
  },
];
