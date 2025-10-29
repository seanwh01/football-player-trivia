/**
 * Cloud Functions for Pigskin Genius - NFL Football Trivia
 * 
 * Secure backend proxy for OpenAI API calls with:
 * - Rate limiting
 * - Caching
 * - Budget controls
 * - Fallback mechanisms
 */

const functions = require('firebase-functions');
const OpenAI = require('openai');
const NodeCache = require('node-cache');
const natural = require('natural');

// Initialize OpenAI with Firebase config (key stored securely in Firebase)
const openai = new OpenAI({
  apiKey: functions.config().openai.key
});

// Cache for 30 days (2592000 seconds) - player names don't change!
// Increase this in production to save costs long-term
const cache = new NodeCache({ stdTTL: 2592000 });

// Budget tracking (resets daily)
let dailySpending = 0;
let lastResetDate = new Date().toDateString();

// Configuration
const CONFIG = {
  DAILY_BUDGET_LIMIT: 50, // $50 per day max
  MAX_HINTS_PER_USER_PER_DAY: 2000, // Generous for users, blocks bots
  MAX_VALIDATIONS_PER_USER_PER_DAY: 5000, // High limit for answer submissions
  CACHE_ENABLED: true,  // ENABLED for production - 30-day cache for cost savings
  CACHE_VERSION: 'v5_fixed_initials',  // Fixed: initials now correctly use first+last (AB not AJ for AJ Brown)
  COST_PER_VALIDATION: 0.0005,
  COST_PER_HINT: 0.0003
};

// Simple in-memory rate limiting (for demo - use Firestore for production)
const userRateLimits = new Map();

/**
 * Reset daily budget if it's a new day
 */
function checkAndResetDailyBudget() {
  const today = new Date().toDateString();
  if (today !== lastResetDate) {
    console.log(`Resetting daily budget. Previous: $${dailySpending}`);
    dailySpending = 0;
    lastResetDate = today;
    userRateLimits.clear(); // Reset user limits too
  }
}

/**
 * Check if daily budget is exceeded
 */
function checkBudget(cost) {
  checkAndResetDailyBudget();
  
  if (dailySpending + cost > CONFIG.DAILY_BUDGET_LIMIT) {
    console.warn(`Daily budget exceeded: $${dailySpending}/$${CONFIG.DAILY_BUDGET_LIMIT}`);
    return false;
  }
  return true;
}

/**
 * Increment daily spending
 */
function incrementSpending(cost) {
  dailySpending += cost;
  console.log(`Daily spending: $${dailySpending.toFixed(4)}/$${CONFIG.DAILY_BUDGET_LIMIT}`);
}

/**
 * Check rate limit for a user
 */
function checkRateLimit(userId, action) {
  checkAndResetDailyBudget();
  
  const key = `${userId}_${action}`;
  const current = userRateLimits.get(key) || 0;
  
  const limit = action === 'hint' 
    ? CONFIG.MAX_HINTS_PER_USER_PER_DAY 
    : CONFIG.MAX_VALIDATIONS_PER_USER_PER_DAY;
  
  if (current >= limit) {
    console.warn(`Rate limit exceeded for user ${userId}: ${current}/${limit} ${action}s`);
    return false;
  }
  
  return true;
}

/**
 * Increment rate limit counter
 */
function incrementRateLimit(userId, action) {
  const key = `${userId}_${action}`;
  const current = userRateLimits.get(key) || 0;
  userRateLimits.set(key, current + 1);
}

/**
 * Generate cache key for validation
 * Includes version so we can invalidate cache when logic changes
 */
function getValidationCacheKey(data) {
  const playerNames = data.correctPlayers
    .map(p => `${p.firstName}_${p.lastName}`)
    .sort()
    .join('|');
  return `${CONFIG.CACHE_VERSION}_val_${data.position}_${data.year}_${data.team}_${playerNames}_${data.userAnswer.toLowerCase()}`;
}

/**
 * Generate cache key for hints
 * Includes version so we can invalidate cache when logic changes
 */
function getHintCacheKey(data) {
  const playerNames = data.correctPlayers
    .map(p => `${p.firstName}_${p.lastName}`)
    .sort()
    .join('|');
  const level = data.hintLevel || 'General';
  return `${CONFIG.CACHE_VERSION}_hint_${data.position}_${data.year}_${data.team}_${playerNames}_${level}`;
}

/**
 * Compute cosine similarity between two vectors
 */
function cosineSimilarity(vecA, vecB) {
  const dotProduct = vecA.reduce((sum, a, i) => sum + a * vecB[i], 0);
  const magnitudeA = Math.sqrt(vecA.reduce((sum, a) => sum + a * a, 0));
  const magnitudeB = Math.sqrt(vecB.reduce((sum, b) => sum + b * b, 0));
  return dotProduct / (magnitudeA * magnitudeB);
}

/**
 * Check if two strings match phonetically using Metaphone
 * Returns true if the phonetic codes match
 */
function phoneticMatch(str1, str2) {
  const metaphone = natural.Metaphone;
  const code1 = metaphone.process(str1);
  const code2 = metaphone.process(str2);
  
  return code1 === code2;
}

/**
 * Check if user's answer matches any player using phonetic matching
 * This is FREE and catches common misspellings like "Drew" vs "Drue"
 * Returns: { isMatch, matchedPlayer, matchType }
 */
function checkPhoneticMatch(userAnswer, correctPlayers) {
  const userClean = userAnswer.toLowerCase().trim();
  
  // Split user answer into words
  const userWords = userClean.split(/\s+/);
  
  for (const player of correctPlayers) {
    const firstName = player.firstName.toLowerCase();
    const lastName = player.lastName.toLowerCase();
    const fullName = `${firstName} ${lastName}`;
    
    // Check full name match
    if (phoneticMatch(userClean, fullName)) {
      return { isMatch: true, matchedPlayer: player, matchType: 'phonetic_full' };
    }
    
    // Check last name only
    if (phoneticMatch(userClean, lastName)) {
      return { isMatch: true, matchedPlayer: player, matchType: 'phonetic_last' };
    }
    
    // Check first name only
    if (phoneticMatch(userClean, firstName)) {
      return { isMatch: true, matchedPlayer: player, matchType: 'phonetic_first' };
    }
    
    // Check if user provided two words that match first and last
    if (userWords.length === 2) {
      if (phoneticMatch(userWords[0], firstName) && phoneticMatch(userWords[1], lastName)) {
        return { isMatch: true, matchedPlayer: player, matchType: 'phonetic_both' };
      }
    }
  }
  
  return { isMatch: false, matchedPlayer: null, matchType: null };
}

/**
 * Check if user's answer is within 2 character edits of correct answer using Levenshtein distance
 * This is FREE and catches typos like "Mahones" vs "Mahomes" (1 edit)
 * Returns: { isMatch, matchedPlayer, matchType, distance }
 */
function checkLevenshteinMatch(userAnswer, correctPlayers, maxDistance = 2) {
  const userClean = userAnswer.toLowerCase().trim();
  
  // Split user answer into words
  const userWords = userClean.split(/\s+/);
  
  for (const player of correctPlayers) {
    const firstName = player.firstName.toLowerCase();
    const lastName = player.lastName.toLowerCase();
    const fullName = `${firstName} ${lastName}`;
    
    // Check full name distance
    const fullNameDist = natural.LevenshteinDistance(userClean, fullName);
    if (fullNameDist <= maxDistance) {
      return { isMatch: true, matchedPlayer: player, matchType: 'levenshtein_full', distance: fullNameDist };
    }
    
    // Check last name only
    const lastNameDist = natural.LevenshteinDistance(userClean, lastName);
    if (lastNameDist <= maxDistance) {
      return { isMatch: true, matchedPlayer: player, matchType: 'levenshtein_last', distance: lastNameDist };
    }
    
    // Check first name only
    const firstNameDist = natural.LevenshteinDistance(userClean, firstName);
    if (firstNameDist <= maxDistance) {
      return { isMatch: true, matchedPlayer: player, matchType: 'levenshtein_first', distance: firstNameDist };
    }
    
    // Check if user provided two words - check each word separately
    if (userWords.length === 2) {
      const firstWordDist = natural.LevenshteinDistance(userWords[0], firstName);
      const lastWordDist = natural.LevenshteinDistance(userWords[1], lastName);
      
      // Allow ≤2 total edits across both names
      if (firstWordDist + lastWordDist <= maxDistance) {
        return { isMatch: true, matchedPlayer: player, matchType: 'levenshtein_both', distance: firstWordDist + lastWordDist };
      }
    }
  }
  
  return { isMatch: false, matchedPlayer: null, matchType: null, distance: null };
}

/**
 * Check if user's answer matches using embedding similarity
 * Returns: { isMatch, similarity, matchedPlayer }
 * Threshold: 0.78 accepts ~2-3 character differences (e.g., "Isaah" for "Isiah")
 */
async function checkNameSimilarity(userAnswer, correctPlayers, threshold = 0.78) {
  try {
    const userAnswerClean = userAnswer.toLowerCase().trim();
    
    // Check for initials (reject immediately)
    if (userAnswerClean.length < 3 || /^[a-z]\.?[a-z]\.?$/i.test(userAnswerClean)) {
      return { isMatch: false, similarity: 0, matchedPlayer: null, reason: 'initials' };
    }
    
    // Get embedding for user's answer
    const userEmbedding = await openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: userAnswerClean
    });
    
    const userVector = userEmbedding.data[0].embedding;
    
    // Check similarity against each correct player
    let bestMatch = { similarity: 0, player: null, isExact: false };
    
    for (const player of correctPlayers) {
      const fullName = `${player.firstName} ${player.lastName}`.toLowerCase();
      const firstName = player.firstName.toLowerCase();
      const lastName = player.lastName.toLowerCase();
      
      // Check exact matches first (avoid API calls)
      if (userAnswerClean === fullName || userAnswerClean === firstName || userAnswerClean === lastName) {
        bestMatch = { similarity: 1.0, player, isExact: true };
        break;
      }
      
      // Get embeddings for all variations
      const nameEmbeddings = await openai.embeddings.create({
        model: 'text-embedding-3-small',
        input: [fullName, lastName, firstName]
      });
      
      // Check similarity with full name
      const fullNameSim = cosineSimilarity(userVector, nameEmbeddings.data[0].embedding);
      // Check similarity with last name only (very forgiving)
      const lastNameSim = cosineSimilarity(userVector, nameEmbeddings.data[1].embedding);
      // Check similarity with first name only
      const firstNameSim = cosineSimilarity(userVector, nameEmbeddings.data[2].embedding);
      
      // Use the best similarity score
      const maxSim = Math.max(fullNameSim, lastNameSim, firstNameSim);
      
      if (maxSim > bestMatch.similarity) {
        bestMatch = { similarity: maxSim, player, isExact: false };
      }
    }
    
    return {
      isMatch: bestMatch.similarity >= threshold,
      similarity: bestMatch.similarity,
      matchedPlayer: bestMatch.player,
      isExact: bestMatch.isExact
    };
  } catch (error) {
    console.error('Error in checkNameSimilarity:', error);
    return { isMatch: false, similarity: 0, matchedPlayer: null, reason: 'error' };
  }
}

/**
 * Fallback validation (simple string matching)
 */
function fallbackValidation(data) {
  const userAnswer = data.userAnswer.toLowerCase().trim();
  
  const correctNames = data.correctPlayers.map(p => ({
    first: p.firstName.toLowerCase(),
    last: p.lastName.toLowerCase(),
    full: `${p.firstName} ${p.lastName}`.toLowerCase()
  }));
  
  // Check if answer matches any player
  const isCorrect = correctNames.some(names => 
    userAnswer === names.first || 
    userAnswer === names.last || 
    userAnswer === names.full
  );
  
  if (isCorrect) {
    const matchedPlayer = data.correctPlayers.find(p => {
      const full = `${p.firstName} ${p.lastName}`.toLowerCase();
      return userAnswer === p.firstName.toLowerCase() || 
             userAnswer === p.lastName.toLowerCase() || 
             userAnswer === full;
    });
    return {
      isCorrect: true,
      message: `✅ Correct!\n\n${matchedPlayer.firstName} ${matchedPlayer.lastName} was the right answer!`
    };
  } else {
    const allNames = data.correctPlayers.map(p => `${p.firstName} ${p.lastName}`).join(', ');
    return {
      isCorrect: false,
      message: `❌ Sorry, the correct answer${data.correctPlayers.length > 1 ? 's were' : ' was'}: ${allNames}`
    };
  }
}

/**
 * CLOUD FUNCTION: Validate Answer
 * 
 * Uses text-embedding-3-small to compute cosine similarity between user's answer
 * and correct player names. Threshold: 0.78 (accepts 2-3 character differences).
 * GPT-4o-mini generates flavor text only.
 */
exports.validateAnswer = functions.https.onCall(async (data, context) => {
  try {
    // Get user ID (anonymous or authenticated)
    const userId = context.auth ? context.auth.uid : 'anonymous';
    
    console.log(`Validation request from user: ${userId}`);
    
    // 1. Check rate limit
    if (!checkRateLimit(userId, 'validation')) {
      return {
        error: 'rate_limit',
        message: "You've reached your daily limit of validations. Try again tomorrow!",
        fallback: fallbackValidation(data)
      };
    }
    
    // 2. Check cache - stores full validation result (embeddings + GPT facts)
    if (CONFIG.CACHE_ENABLED) {
      const cacheKey = getValidationCacheKey(data);
      const cached = cache.get(cacheKey);
      if (cached) {
        console.log('Cache hit for validation');
        incrementRateLimit(userId, 'validation');
        return cached;
      }
    }
    
    // 3. Check budget
    if (!checkBudget(CONFIG.COST_PER_VALIDATION)) {
      console.warn('Budget exceeded, using fallback');
      return {
        error: 'budget_exceeded',
        message: 'Service temporarily at capacity. Using basic validation.',
        fallback: fallbackValidation(data)
      };
    }
    
    // 4. First try phonetic matching (FREE - no API call!)
    const phoneticResult = checkPhoneticMatch(data.userAnswer, data.correctPlayers);
    
    if (phoneticResult.isMatch) {
      console.log(`✅ Phonetic match found! Type: ${phoneticResult.matchType} (saved API cost)`);
      
      // Use phonetic match result - treat as correct but acknowledge spelling
      const matchedName = `${phoneticResult.matchedPlayer.firstName} ${phoneticResult.matchedPlayer.lastName}`;
      const isExactSpelling = data.userAnswer.toLowerCase().trim() === matchedName.toLowerCase();
      
      let prompt;
      if (isExactSpelling) {
        prompt = `You are an NFL trivia judge and storyteller.

The user correctly guessed: ${matchedName}
Position: ${data.position}, Team: ${data.team}, Year: ${data.year}

Start with "✅ Correct!" on its own line, then provide 2-3 interesting facts about ${matchedName}, including personal info (birthplace, college, interesting backstory) and NFL achievements from around ${data.year}. Make it engaging and fun! Keep it concise (2-3 sentences total after the first line).`;
      } else {
        prompt = `You are an NFL trivia judge and storyteller.

The user guessed "${data.userAnswer}" which sounds like: ${matchedName}
Position: ${data.position}, Team: ${data.team}, Year: ${data.year}

Start with "✅ Correct! (The spelling is ${matchedName})" on its own line, then provide 2-3 interesting facts about the player. Acknowledge their answer was phonetically correct! Keep it concise (2-3 sentences total after the first line).`;
      }
      
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'You are a knowledgeable and enthusiastic NFL trivia host who makes learning about players fun and interesting. Generate engaging facts and stories about NFL players. Keep responses concise (2-3 sentences after the emoji line).'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        max_tokens: 200,
        temperature: 0.7
      });
      
      const message = completion.choices[0].message.content.trim();
      
      const result = {
        isCorrect: true,
        message
      };
      
      incrementSpending(CONFIG.COST_PER_VALIDATION);
      incrementRateLimit(userId, 'validation');
      
      if (CONFIG.CACHE_ENABLED) {
        const cacheKey = getValidationCacheKey(data);
        cache.set(cacheKey, result);
      }
      
      return result;
    }
    
    // 5. Try Levenshtein distance check (FREE - catches typos like "Mahones" vs "Mahomes")
    const levenshteinResult = checkLevenshteinMatch(data.userAnswer, data.correctPlayers, 2);
    
    if (levenshteinResult.isMatch) {
      console.log(`✅ Levenshtein match found! Type: ${levenshteinResult.matchType}, Distance: ${levenshteinResult.distance} (saved API cost)`);
      
      // Use Levenshtein match result - treat as correct but acknowledge typo
      const matchedName = `${levenshteinResult.matchedPlayer.firstName} ${levenshteinResult.matchedPlayer.lastName}`;
      const isExactSpelling = data.userAnswer.toLowerCase().trim() === matchedName.toLowerCase();
      
      let prompt;
      if (isExactSpelling) {
        prompt = `You are an NFL trivia judge and storyteller.

The user correctly guessed: ${matchedName}
Position: ${data.position}, Team: ${data.team}, Year: ${data.year}

Start with "✅ Correct!" on its own line, then provide 2-3 interesting facts about ${matchedName}, including personal info (birthplace, college, interesting backstory) and NFL achievements from around ${data.year}. Make it engaging and fun! Keep it concise (2-3 sentences total after the first line).`;
      } else {
        prompt = `You are an NFL trivia judge and storyteller.

The user guessed "${data.userAnswer}" which is very close to: ${matchedName}
Position: ${data.position}, Team: ${data.team}, Year: ${data.year}

Start with "✅ Close enough! The correct spelling is ${matchedName}." on its own line, then provide 2-3 interesting facts about the player. Acknowledge their answer was almost correct! Keep it concise (2-3 sentences total after the first line).`;
      }
      
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'You are a knowledgeable and enthusiastic NFL trivia host who makes learning about players fun and interesting. Generate engaging facts and stories about NFL players. Keep responses concise (2-3 sentences after the emoji line).'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        max_tokens: 200,
        temperature: 0.7
      });
      
      const message = completion.choices[0].message.content.trim();
      
      const result = {
        isCorrect: true,
        message
      };
      
      incrementSpending(CONFIG.COST_PER_VALIDATION);
      incrementRateLimit(userId, 'validation');
      
      if (CONFIG.CACHE_ENABLED) {
        const cacheKey = getValidationCacheKey(data);
        cache.set(cacheKey, result);
      }
      
      return result;
    }
    
    // 6. If all free checks fail, use embedding similarity for validation
    console.log('No phonetic or Levenshtein match, using embedding similarity...');
    const similarityResult = await checkNameSimilarity(data.userAnswer, data.correctPlayers, 0.78);
    
    console.log(`Similarity check: ${similarityResult.similarity.toFixed(3)} (threshold: 0.78) - ${similarityResult.isMatch ? 'MATCH' : 'NO MATCH'}`);
    
    // If initials or very short, reject but still provide player facts
    if (similarityResult.reason === 'initials') {
      const correctNames = data.correctPlayers.map(p => `${p.firstName} ${p.lastName}`).join(', ');
      
      // Generate flavor text with GPT about the correct player
      const prompt = `You are an NFL trivia judge and storyteller.

The user provided just initials ("${data.userAnswer}") which is not accepted.
The correct answer was: ${correctNames}
Position: ${data.position}, Team: ${data.team}, Year: ${data.year}

Start with "❌ Sorry, please provide actual names, not just initials. The answer was ${correctNames}." on its own line, then provide 2-3 interesting facts about ${correctNames}, including personal info and career highlights. Make it engaging! Keep it concise.`;

      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'You are a knowledgeable and enthusiastic NFL trivia host who makes learning about players fun and interesting. Generate engaging facts and stories about NFL players. Keep responses concise (2-3 sentences after the emoji line).'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        max_tokens: 200,
        temperature: 0.7
      });
      
      const message = completion.choices[0].message.content.trim();
      
      const result = {
        isCorrect: false,
        message
      };
      
      incrementSpending(CONFIG.COST_PER_VALIDATION);
      incrementRateLimit(userId, 'validation');
      
      console.log(`Validation complete: Incorrect - initials rejected`);
      return result;
    }
    
    const correctNames = data.correctPlayers.map(p => `${p.firstName} ${p.lastName}`).join(', ');
    let validationIsCorrect = similarityResult.isMatch;
    const isExact = similarityResult.isExact;
    
    // 7. If embedding check failed, use GPT-4o-mini to check for acceptable nicknames
    if (!validationIsCorrect) {
      console.log('Embedding check failed, checking for acceptable nicknames with GPT-4o-mini...');
      
      const nicknamePrompt = `You are an NFL trivia validator checking if a user's answer is an acceptable nickname or alternate name for a player.

User's answer: "${data.userAnswer}"
Correct player(s): ${correctNames}
Position: ${data.position}, Team: ${data.team}, Year: ${data.year}

Is "${data.userAnswer}" a commonly accepted nickname, shortened name, or alternate name for any of these players?

Examples of acceptable nicknames:
- "Megatron" for Calvin Johnson
- "Beast Mode" for Marshawn Lynch
- "Sweetness" for Walter Payton
- "Prime Time" for Deion Sanders
- "Flash" for Desean Jackson
- "AJ" for A.J. Green
- "Pat" for Patrick Mahomes
- "Josh" for Joshua Allen

Respond with ONLY "YES" or "NO" - nothing else.`;

      const nicknameCheck = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'You are an NFL nickname validator. Respond with only YES or NO.'
          },
          {
            role: 'user',
            content: nicknamePrompt
          }
        ],
        max_tokens: 10,
        temperature: 0
      });
      
      const nicknameResponse = nicknameCheck.choices[0].message.content.trim().toUpperCase();
      
      if (nicknameResponse === 'YES') {
        console.log('✅ Nickname accepted by GPT-4o-mini override!');
        validationIsCorrect = true;
      } else {
        console.log('❌ Nickname not accepted');
      }
    }
    
    // 8. Generate flavor text with GPT (now that we know if it's correct via embeddings or nickname check)
    let prompt;
    if (data.correctPlayers.length === 1) {
      // Single player position
      const matchedName = similarityResult.matchedPlayer ? `${similarityResult.matchedPlayer.firstName} ${similarityResult.matchedPlayer.lastName}` : correctNames;
      
      if (validationIsCorrect && isExact) {
        prompt = `You are an NFL trivia judge and storyteller.

The user correctly guessed: ${matchedName}
Position: ${data.position}, Team: ${data.team}, Year: ${data.year}

Start with "✅ Correct!" on its own line, then provide 2-3 interesting facts about ${matchedName}, including personal info (birthplace, college, interesting backstory) and NFL achievements from around ${data.year}. Make it engaging and fun! Keep it concise (2-3 sentences total after the first line).`;
      } else if (validationIsCorrect && !isExact) {
        // Check if this was a nickname match
        const wasNicknameMatch = !similarityResult.isMatch;
        
        if (wasNicknameMatch) {
          prompt = `You are an NFL trivia judge and storyteller.

The user guessed "${data.userAnswer}" which is an accepted nickname for: ${matchedName}
Position: ${data.position}, Team: ${data.team}, Year: ${data.year}

Start with "✅ Correct! '${data.userAnswer}' is a great nickname for ${matchedName}!" on its own line, then provide 2-3 interesting facts about the player. Acknowledge their creative answer! Keep it concise (2-3 sentences total after the first line).`;
        } else {
          prompt = `You are an NFL trivia judge and storyteller.

The user guessed "${data.userAnswer}" which is close enough to: ${matchedName}
Position: ${data.position}, Team: ${data.team}, Year: ${data.year}

Start with "✅ Close enough! The correct spelling is ${matchedName}." on its own line, then provide 2-3 interesting facts about the player. Acknowledge their answer was close and give them credit! Keep it concise (2-3 sentences total after the first line).`;
        }
      } else {
        prompt = `You are an NFL trivia judge and storyteller.

The user guessed "${data.userAnswer}" but the correct answer was: ${correctNames}
Position: ${data.position}, Team: ${data.team}, Year: ${data.year}

Start with "❌ Sorry, the answer was ${correctNames}." on its own line, then provide 2-3 interesting facts about the correct player, including personal info and career highlights. Make it engaging and help them learn! Keep it concise (2-3 sentences total after the first line).`;
      }
    } else {
      // Multiple player position - determine flavor based on embedding result
      const matchedName = similarityResult.matchedPlayer ? `${similarityResult.matchedPlayer.firstName} ${similarityResult.matchedPlayer.lastName}` : null;
      
      if (validationIsCorrect && isExact && matchedName) {
        prompt = `You are an NFL trivia judge and storyteller.

The user correctly guessed: ${matchedName}
Position: ${data.position}, Team: ${data.team}, Year: ${data.year}
All correct answers were: ${correctNames}

Start with "✅ Correct!" on its own line, then mention which player they guessed and provide 2-3 interesting facts about that player. Also mention the other correct answers. Make it engaging! Keep it concise.`;
      } else if (validationIsCorrect && !isExact && matchedName) {
        prompt = `You are an NFL trivia judge and storyteller.

The user guessed "${data.userAnswer}" which is close enough to: ${matchedName}
Position: ${data.position}, Team: ${data.team}, Year: ${data.year}
All correct answers were: ${correctNames}

Start with "✅ Close enough! You got ${matchedName}." on its own line, then provide 2-3 interesting facts about that player. Acknowledge their answer was close and give them credit! Also mention the other correct answers. Keep it concise.`;
      } else {
        prompt = `You are an NFL trivia judge and storyteller.

The user guessed "${data.userAnswer}" but it didn't match any of the correct players: ${correctNames}
Position: ${data.position}, Team: ${data.team}, Year: ${data.year}

Start with "❌ Sorry, the correct answers were: ${correctNames}." on its own line, then provide 2-3 interesting facts about the most notable player from this group. Make it engaging and help them learn! Keep it concise.`;
      }
    }
    
    // 8. Generate flavor text with GPT
    
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: 'You are a knowledgeable and enthusiastic NFL trivia host who makes learning about players fun and interesting. Generate engaging facts and stories about NFL players. Keep responses concise (2-3 sentences after the emoji line).'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      max_tokens: 200,
      temperature: 0.7
    });
    
    const message = completion.choices[0].message.content.trim();
    
    const result = {
      isCorrect: validationIsCorrect,
      message
    };
    
    // 9. Update tracking
    incrementSpending(CONFIG.COST_PER_VALIDATION);
    incrementRateLimit(userId, 'validation');
    
    // 10. Cache result - stores full LLM output (validation + GPT facts)
    if (CONFIG.CACHE_ENABLED) {
      const cacheKey = getValidationCacheKey(data);
      cache.set(cacheKey, result);
    }
    
    console.log(`Validation complete: ${validationIsCorrect ? 'Correct' : 'Incorrect'} (similarity: ${similarityResult.similarity.toFixed(3)})`);
    return result;
    
  } catch (error) {
    console.error('Error in validateAnswer:', error);
    
    // Return fallback on error
    return {
      error: 'api_error',
      message: 'Error connecting to validation service. Using basic validation.',
      fallback: fallbackValidation(data)
    };
  }
});

/**
 * CLOUD FUNCTION: Generate Hint
 * 
 * Generates a hint for the player using OpenAI
 */
exports.generateHint = functions.https.onCall(async (data, context) => {
  try {
    // Get user ID (anonymous or authenticated)
    const userId = context.auth ? context.auth.uid : 'anonymous';
    
    console.log(`Hint request from user: ${userId}`);
    
    // 1. Check rate limit
    if (!checkRateLimit(userId, 'hint')) {
      return {
        error: 'rate_limit',
        message: "You've reached your daily limit of hints. Try again tomorrow!"
      };
    }
    
    // 2. Check cache
    if (CONFIG.CACHE_ENABLED) {
      const cacheKey = getHintCacheKey(data);
      const cached = cache.get(cacheKey);
      if (cached) {
        console.log('Cache hit for hint');
        incrementRateLimit(userId, 'hint');
        return cached;
      }
    }
    
    // 3. Check budget
    if (!checkBudget(CONFIG.COST_PER_HINT)) {
      console.warn('Budget exceeded for hint');
      return {
        error: 'budget_exceeded',
        message: 'Hints temporarily unavailable due to high demand. Try again later!'
      };
    }
    
    // 4. Call OpenAI
    const correctNames = data.correctPlayers.map(p => `${p.firstName} ${p.lastName}`).join(', ');
    const hintLevel = data.hintLevel || 'General'; // Default to General if not provided
    
    // Determine hint difficulty based on level
    const isMoreObvious = hintLevel === 'More Obvious';
    const difficultyInstruction = isMoreObvious 
      ? 'Provide a more direct and obvious hint that makes it easier to guess.'
      : 'Provide a helpful but subtle hint that requires some thought.';
    
    let prompt;
    if (data.correctPlayers.length === 1) {
      const player = data.correctPlayers[0];
      const initials = `${player.firstName.charAt(0)}${player.lastName.charAt(0)}`;
      
      prompt = `You are an NFL trivia expert. The user is trying to guess an NFL player with these details:
- Position: ${data.position}
- Team: ${data.team}
- Year: ${data.year}

The correct answer is: ${correctNames}

${difficultyInstruction}
${isMoreObvious ? 'Use more specific details like notable awards, records, or distinguishing characteristics.' : 'Use interesting NFL facts from their career that are somewhat subtle.'}
Do NOT use phonetics, rhymes, or wordplay as hints.
Do NOT reveal their name directly.
Keep the hint to 1-2 sentences.
Focus on memorable achievements, statistics, nicknames, or career highlights from around that year.
${isMoreObvious ? `\n\nIMPORTANT: End your hint with a new line, then add exactly this text: "This player's initials are ${initials} and they played college football at [college name]." You MUST research and include the actual college name.` : ''}`;
    } else {
      let count = 'two';
      let positionLabel = data.position + 's';
      
      if (data.position === 'Offensive Linemen') {
        count = 'five';
        positionLabel = 'offensive linemen';
      } else if (data.position === 'Defensive Back') {
        count = 'four';
        positionLabel = 'defensive backs';
      } else if (['Wide Receiver', 'Linebacker', 'Defensive Linemen'].includes(data.position)) {
        count = 'three';
      }
      
      // Calculate initials for all players
      const playerInitials = data.correctPlayers.map(p => {
        const firstInitial = p.firstName.charAt(0);
        const lastInitial = p.lastName.charAt(0);
        return `${p.firstName} ${p.lastName}: ${firstInitial}${lastInitial}`;
      }).join(', ');
      
      prompt = `You are an NFL trivia expert. The user is trying to guess one of the top ${count} ${positionLabel} by snaps played with these details:
- Team: ${data.team}
- Year: ${data.year}

The correct answers are: ${correctNames}

Provide a hint about ONE of these players (pick the most famous or interesting one) using NFL facts.
${difficultyInstruction}
${isMoreObvious ? 'Use more specific details like notable awards, records, or distinguishing characteristics.' : 'Use interesting NFL facts that are somewhat subtle.'}
Do NOT use phonetics, rhymes, or wordplay as hints.
Do NOT reveal any names directly.
Keep the hint to 1-2 sentences.
Focus on memorable achievements, statistics, or nicknames from around that year.
${isMoreObvious ? `\n\nIMPORTANT: After your hint, add a new line and then add exactly this format: "This player's initials are XX and they played college football at [college name]." Use the CORRECT initials for whichever player you chose to hint about. The initials are: ${playerInitials}. For example, if the player's name is "AJ Brown", the initials are AB (first letter of first name + first letter of last name). Research and include the actual college name.` : ''}`;
    }
    
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: 'You are a helpful NFL trivia assistant that provides clever hints without giving away the answer directly.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      max_tokens: 100,
      temperature: 0.7
    });
    
    const hint = completion.choices[0].message.content.trim();
    
    const result = { hint };
    
    // 5. Update tracking
    incrementSpending(CONFIG.COST_PER_HINT);
    incrementRateLimit(userId, 'hint');
    
    // 6. Cache result
    if (CONFIG.CACHE_ENABLED) {
      const cacheKey = getHintCacheKey(data);
      cache.set(cacheKey, result);
    }
    
    console.log('Hint generated successfully');
    return result;
    
  } catch (error) {
    console.error('Error in generateHint:', error);
    return {
      error: 'api_error',
      message: 'Unable to generate hint at this time. Please try again.'
    };
  }
});

/**
 * CLOUD FUNCTION: Get Budget Status (for monitoring)
 * Admin only
 */
exports.getBudgetStatus = functions.https.onCall(async (data, context) => {
  checkAndResetDailyBudget();
  
  return {
    dailySpending: dailySpending.toFixed(4),
    dailyLimit: CONFIG.DAILY_BUDGET_LIMIT,
    percentageUsed: ((dailySpending / CONFIG.DAILY_BUDGET_LIMIT) * 100).toFixed(1),
    lastReset: lastResetDate,
    cacheSize: cache.keys().length
  };
});
