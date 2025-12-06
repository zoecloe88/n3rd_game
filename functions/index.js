const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {GoogleGenerativeAI} = require("@google/generative-ai");
const Anthropic = require("@anthropic-ai/sdk");

initializeApp();
const db = getFirestore();

// Initialize AI clients (API keys stored in Firebase Secrets)
// To set secrets: firebase functions:secrets:set GEMINI_API_KEY
// To access: process.env.GEMINI_API_KEY (automatically loaded from secrets)
const genAI = process.env.GEMINI_API_KEY 
  ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY)
  : null;

const anthropic = process.env.ANTHROPIC_API_KEY
  ? new Anthropic({apiKey: process.env.ANTHROPIC_API_KEY})
  : null;

// Prohibited topics for content moderation
const PROHIBITED_TOPICS = [
  "violence", "weapons", "drugs", "alcohol", "gambling", "tobacco",
  "explicit", "adult", "mature", "inappropriate", "offensive",
  "hate", "discrimination", "racism", "sexism", "harassment",
  "suicide", "self-harm", "gore", "torture", "murder", "kill",
  "porn", "sexual", "nude", "nudity", "erotic", "xxx",
];

/**
 * Generate trivia using AI
 * Called from client with authenticated user
 */
exports.generateTrivia = onCall(
  {
    maxInstances: 10,
    timeoutSeconds: 60,
    memory: "512MiB",
    invoker: "private", // Only allow authenticated calls
  },
  async (request) => {
    // Verify authentication
    const authToken = request.auth;
    if (!authToken) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    // Verify user is premium (check subscription status)
    const userId = authToken.uid;
    let userData;
    try {
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists) {
        throw new HttpsError("permission-denied", "User profile not found");
      }
      
      userData = userDoc.data();
      const subscriptionTier = userData?.subscriptionTier || "free";
      
      if (subscriptionTier !== "premium") {
        throw new HttpsError(
          "permission-denied",
          "Premium subscription required for AI Edition"
        );
      }
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      // If Firestore check fails, fall back to checking SharedPreferences pattern
      // For now, we'll be strict and require premium
      throw new HttpsError(
        "permission-denied",
        "Unable to verify subscription status"
      );
    }

    // Server-side rate limiting (20 requests per day per user)
    const today = new Date().toISOString().split("T")[0];
    const rateLimitKey = `ai_generation_${userId}_${today}`;
    const rateLimitDoc = await db.collection("rate_limits").doc(rateLimitKey).get();
    
    const dailyLimit = 20;
    let requestCount = 0;
    
    if (rateLimitDoc.exists) {
      requestCount = rateLimitDoc.data()?.count || 0;
      if (requestCount >= dailyLimit) {
        throw new HttpsError(
          "resource-exhausted",
          `Daily limit of ${dailyLimit} AI generations reached. Please try again tomorrow.`
        );
      }
    }

    const {topic, isYouthEdition, count} = request.data || {};

    // Comprehensive input validation
    if (!topic || typeof topic !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Topic must be a non-empty string"
      );
    }

    const sanitizedTopic = topic.trim();
    if (sanitizedTopic.length < 2) {
      throw new HttpsError(
        "invalid-argument",
        "Topic must be at least 2 characters"
      );
    }

    if (sanitizedTopic.length > 100) {
      throw new HttpsError(
        "invalid-argument",
        "Topic must be 100 characters or less"
      );
    }

    if (typeof count !== "number" || !Number.isInteger(count)) {
      throw new HttpsError(
        "invalid-argument",
        "Count must be an integer"
      );
    }

    if (count < 1 || count > 100) {
      throw new HttpsError(
        "invalid-argument",
        "Count must be between 1 and 100"
      );
    }

    if (typeof isYouthEdition !== "boolean") {
      throw new HttpsError(
        "invalid-argument",
        "isYouthEdition must be a boolean"
      );
    }

    // Content moderation with enhanced validation
    const topicLower = sanitizedTopic.toLowerCase();
    
    // Check for prohibited topics
    for (const prohibited of PROHIBITED_TOPICS) {
      if (topicLower.includes(prohibited)) {
        console.warn(`Blocked inappropriate topic: ${sanitizedTopic} by user ${userId}`);
        throw new HttpsError(
          "permission-denied",
          "Topic contains inappropriate content"
        );
      }
    }

    // Additional checks for youth editions
    if (isYouthEdition) {
      const adultThemes = ["dating", "romance", "relationship", "marriage", "adult", "mature"];
      for (const theme of adultThemes) {
        if (topicLower.includes(theme)) {
          console.warn(`Blocked adult theme for youth: ${sanitizedTopic} by user ${userId}`);
          throw new HttpsError(
            "permission-denied",
            "Topic is not suitable for youth editions"
          );
        }
      }
    }

    // Log request for monitoring
    console.log(`AI generation request: userId=${userId}, topic=${sanitizedTopic}, count=${count}, isYouth=${isYouthEdition}`);

    try {
      // Check cache first (reduce API costs)
      const cacheKey = `ai_cache_${sanitizedTopic.toLowerCase()}_${count}_${isYouthEdition}`;
      const cacheDoc = await db.collection("ai_cache").doc(cacheKey).get();
      
      if (cacheDoc.exists) {
        const cacheData = cacheDoc.data();
        const cacheAge = Date.now() - (cacheData?.timestamp || 0);
        const cacheMaxAge = 24 * 60 * 60 * 1000; // 24 hours
        
        if (cacheAge < cacheMaxAge && cacheData?.trivia) {
          console.log(`Cache hit for topic: ${sanitizedTopic}`);
          // Increment rate limit after successful cache hit
          await db.collection("rate_limits").doc(rateLimitKey).set({
            count: requestCount + 1,
            lastRequest: Date.now(),
            userId: userId,
          }, {merge: true});
          
          return {
            success: true,
            trivia: cacheData.trivia,
            provider: cacheData.provider || "cached",
            cached: true,
          };
        }
      }

      // Try Gemini first (preferred - free tier available)
      if (genAI) {
        try {
          const trivia = await Promise.race([
            generateWithGemini(sanitizedTopic, isYouthEdition, count),
            new Promise((_, reject) => 
              setTimeout(() => reject(new Error("Timeout")), 55000)
            ),
          ]);
          
          if (trivia && trivia.length > 0) {
            // Cache the result
            await db.collection("ai_cache").doc(cacheKey).set({
              trivia: trivia,
              provider: "gemini",
              timestamp: Date.now(),
              topic: sanitizedTopic,
            }, {merge: true});
            
            // Increment rate limit
            await db.collection("rate_limits").doc(rateLimitKey).set({
              count: requestCount + 1,
              lastRequest: Date.now(),
              userId: userId,
            }, {merge: true});
            
            console.log(`Successfully generated ${trivia.length} trivia items using Gemini`);
            return {
              success: true,
              trivia: trivia,
              provider: "gemini",
            };
          }
        } catch (error) {
          console.error("Gemini generation failed:", error.message);
          // Fall through to try other providers
        }
      }

      // Try Anthropic if Gemini failed or not available
      if (anthropic) {
        try {
          const trivia = await Promise.race([
            generateWithAnthropic(sanitizedTopic, isYouthEdition, count),
            new Promise((_, reject) => 
              setTimeout(() => reject(new Error("Timeout")), 55000)
            ),
          ]);
          
          if (trivia && trivia.length > 0) {
            // Cache the result
            await db.collection("ai_cache").doc(cacheKey).set({
              trivia: trivia,
              provider: "anthropic",
              timestamp: Date.now(),
              topic: sanitizedTopic,
            }, {merge: true});
            
            // Increment rate limit
            await db.collection("rate_limits").doc(rateLimitKey).set({
              count: requestCount + 1,
              lastRequest: Date.now(),
              userId: userId,
            }, {merge: true});
            
            console.log(`Successfully generated ${trivia.length} trivia items using Anthropic`);
            return {
              success: true,
              trivia: trivia,
              provider: "anthropic",
            };
          }
        } catch (error) {
          console.error("Anthropic generation failed:", error.message);
        }
      }

      // If all AI providers fail, return error (client will use template-based fallback)
      console.error(`All AI providers failed for topic: ${sanitizedTopic}`);
      throw new HttpsError(
        "unavailable",
        "AI generation temporarily unavailable. Please try again later or use template-based generation."
      );
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Trivia generation error:", error);
      throw new HttpsError(
        "internal",
        "Failed to generate trivia. Please try again later."
      );
    }
  }
);

/**
 * Generate trivia using Google Gemini
 */
async function generateWithGemini(topic, isYouth, count) {
  const model = genAI.getGenerativeModel({
    model: "gemini-1.5-flash",
    safetySettings: [
      {
        category: "HARM_CATEGORY_HARASSMENT",
        threshold: "BLOCK_MEDIUM_AND_ABOVE",
      },
      {
        category: "HARM_CATEGORY_HATE_SPEECH",
        threshold: "BLOCK_MEDIUM_AND_ABOVE",
      },
      {
        category: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
        threshold: "BLOCK_MEDIUM_AND_ABOVE",
      },
      {
        category: "HARM_CATEGORY_DANGEROUS_CONTENT",
        threshold: "BLOCK_MEDIUM_AND_ABOVE",
      },
    ],
  });

  const youthNote = isYouth
    ? " This is for a youth/children's edition, so keep all content age-appropriate, educational, and positive."
    : "";

  const prompt = `Generate ${count} trivia questions about "${topic}".${youthNote}

For each trivia question, provide:
1. A category pattern (e.g., "These are [category]")
2. A list of 10-15 correct answers
3. A list of 15-20 distractor answers (wrong answers that are plausible but clearly incorrect)

Format your response as a JSON array where each item has:
- "categoryPattern": "These are [category related to ${topic}]"
- "correctPool": ["answer1", "answer2", ...]
- "distractorPool": ["wrong1", "wrong2", ...]

Make sure:
- Correct answers are all valid examples of the category
- Distractors are related but clearly wrong (different category, wrong type, etc.)
- Content is educational and appropriate
- Categories are diverse and interesting

Return ONLY valid JSON, no markdown, no code blocks, just the JSON array.`;

  const result = await model.generateContent(prompt);
  const responseText = result.response.text();

  if (!responseText) {
    return [];
  }

  // Parse JSON response
  let jsonText = responseText.trim();
  if (jsonText.startsWith("```json")) {
    jsonText = jsonText.substring(7);
  }
  if (jsonText.startsWith("```")) {
    jsonText = jsonText.substring(3);
  }
  if (jsonText.endsWith("```")) {
    jsonText = jsonText.substring(0, jsonText.length - 3);
  }
  jsonText = jsonText.trim();

  const jsonData = JSON.parse(jsonText);
  const triviaItems = [];

  for (const item of jsonData) {
    const categoryPattern = item.categoryPattern || "Trivia";
    const correctPool = item.correctPool || [];
    const distractorPool = item.distractorPool || [];

    if (correctPool.length === 0) continue;

    // Combine and shuffle words
    const allWords = [...correctPool, ...distractorPool];
    shuffleArray(allWords);

    // Apply content moderation
    const categoryLower = categoryPattern.toLowerCase();
    let isProhibited = false;
    for (const prohibited of PROHIBITED_TOPICS) {
      if (categoryLower.includes(prohibited)) {
        isProhibited = true;
        break;
      }
    }
    if (isProhibited) continue;

    triviaItems.push({
      category: categoryPattern
        .replace(/^These are /i, "")
        .replace(/^these are /i, ""),
      words: allWords,
      correctAnswers: correctPool,
    });
  }

  return triviaItems.slice(0, count);
}

/**
 * Generate trivia using Anthropic Claude
 */
async function generateWithAnthropic(topic, isYouth, count) {
  const youthNote = isYouth
    ? " This is for a youth/children's edition, so keep all content age-appropriate, educational, and positive."
    : "";

  const prompt = `Generate ${count} trivia questions about "${topic}".${youthNote}

For each trivia question, provide:
1. A category pattern (e.g., "These are [category]")
2. A list of 10-15 correct answers
3. A list of 15-20 distractor answers (wrong answers that are plausible but clearly incorrect)

Format your response as a JSON array where each item has:
- "categoryPattern": "These are [category related to ${topic}]"
- "correctPool": ["answer1", "answer2", ...]
- "distractorPool": ["wrong1", "wrong2", ...]

Make sure:
- Correct answers are all valid examples of the category
- Distractors are related but clearly wrong (different category, wrong type, etc.)
- Content is educational and appropriate
- Categories are diverse and interesting

Return ONLY valid JSON, no markdown, no code blocks, just the JSON array.`;

  const message = await anthropic.messages.create({
    model: "claude-3-5-sonnet-20241022",
    max_tokens: 8192,
    temperature: 0.7,
    messages: [
      {
        role: "user",
        content: prompt,
      },
    ],
    system: isYouth 
      ? "You are an educational content generator for children. Always create age-appropriate, positive, and educational content."
      : "You are an educational trivia content generator. Create accurate, engaging, and educational trivia questions.",
  });

  const responseText = message.content[0].text;

  if (!responseText) {
    return [];
  }

  // Parse JSON response
  let jsonText = responseText.trim();
  if (jsonText.startsWith("```json")) {
    jsonText = jsonText.substring(7);
  }
  if (jsonText.startsWith("```")) {
    jsonText = jsonText.substring(3);
  }
  if (jsonText.endsWith("```")) {
    jsonText = jsonText.substring(0, jsonText.length - 3);
  }
  jsonText = jsonText.trim();

  const jsonData = JSON.parse(jsonText);
  const triviaItems = [];

  for (const item of jsonData) {
    const categoryPattern = item.categoryPattern || "Trivia";
    const correctPool = item.correctPool || [];
    const distractorPool = item.distractorPool || [];

    if (correctPool.length === 0) continue;

    // Combine and shuffle words
    const allWords = [...correctPool, ...distractorPool];
    shuffleArray(allWords);

    // Apply content moderation
    const categoryLower = categoryPattern.toLowerCase();
    let isProhibited = false;
    for (const prohibited of PROHIBITED_TOPICS) {
      if (categoryLower.includes(prohibited)) {
        isProhibited = true;
        break;
      }
    }
    if (isProhibited) continue;

    triviaItems.push({
      category: categoryPattern
        .replace(/^These are /i, "")
        .replace(/^these are /i, ""),
      words: allWords,
      correctAnswers: correctPool,
    });
  }

  return triviaItems.slice(0, count);
}

/**
 * Shuffle array in place
 */
function shuffleArray(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
}

/**
 * Validate multiplayer room operations (server-side security)
 * Called before critical room operations to ensure user is authorized
 */
exports.validateMultiplayerRoom = onCall(
  {
    maxInstances: 20,
    timeoutSeconds: 10,
    memory: "256MiB",
    invoker: "private", // Only allow authenticated calls
  },
  async (request) => {
    // Verify authentication
    const authToken = request.auth;
    if (!authToken) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const userId = authToken.uid;
    const {roomId, operation} = request.data || {};

    if (!roomId || typeof roomId !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Room ID is required"
      );
    }

    if (!operation || typeof operation !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Operation type is required"
      );
    }

    try {
      // Get room document
      const roomDoc = await db.collection("game_rooms").doc(roomId).get();
      
      if (!roomDoc.exists) {
        throw new HttpsError("not-found", "Room does not exist");
      }

      const roomData = roomDoc.data();
      const players = roomData?.players || [];
      
      // Check if user is in the players array
      const isPlayer = players.some(p => p.userId === userId);
      const isHost = roomData?.hostId === userId;

      // Validate operation-specific permissions
      switch (operation) {
        case "join":
          // Anyone can join if room is waiting and not full
          if (roomData?.status !== "waiting") {
            throw new HttpsError(
              "permission-denied",
              "Room is not accepting new players"
            );
          }
          if (players.length >= (roomData?.maxPlayers || 4)) {
            throw new HttpsError(
              "permission-denied",
              "Room is full"
            );
          }
          break;

        case "update":
        case "submit_answer":
        case "send_message":
          // Only players in the room can perform these operations
          if (!isPlayer && !isHost) {
            throw new HttpsError(
              "permission-denied",
              "You are not a member of this room"
            );
          }
          break;

        case "delete":
        case "start_game":
        case "end_game":
          // Only host can perform these operations
          if (!isHost) {
            throw new HttpsError(
              "permission-denied",
              "Only the room host can perform this operation"
            );
          }
          break;

        default:
          throw new HttpsError(
            "invalid-argument",
            `Unknown operation: ${operation}`
          );
      }

      return {
        success: true,
        isHost: isHost,
        isPlayer: isPlayer,
        roomStatus: roomData?.status,
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Multiplayer room validation error:", error);
      throw new HttpsError(
        "internal",
        "Failed to validate room operation"
      );
    }
  }
);

