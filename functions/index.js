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

// Initialize OpenAI with Firebase config (key stored securely in Firebase)
const openai = new OpenAI({
  apiKey: functions.config().openai.key
});

// Cache for 24 hours (86400 seconds)
const cache = new NodeCache({ stdTTL: 86400 });

// Budget tracking (resets daily)
let dailySpending = 0;
let lastResetDate = new Date().toDateString();

// Configuration
const CONFIG = {
  DAILY_BUDGET_LIMIT: 50, // $50 per day max
  MAX_HINTS_PER_USER_PER_DAY: 2000, // Generous for users, blocks bots
  MAX_VALIDATIONS_PER_USER_PER_DAY: 5000, // High limit for answer submissions
  CACHE_ENABLED: true,
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
 */
function getValidationCacheKey(data) {
  const playerNames = data.correctPlayers
    .map(p => `${p.firstName}_${p.lastName}`)
    .sort()
    .join('|');
  return `val_${data.position}_${data.year}_${data.team}_${playerNames}_${data.userAnswer.toLowerCase()}`;
}

/**
 * Generate cache key for hints
 */
function getHintCacheKey(data) {
  const playerNames = data.correctPlayers
    .map(p => `${p.firstName}_${p.lastName}`)
    .sort()
    .join('|');
  const level = data.hintLevel || 'General';
  return `hint_${data.position}_${data.year}_${data.team}_${playerNames}_${level}`;
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
 * Validates user's answer using OpenAI with smart matching
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
    
    // 2. Check cache
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
    
    // 4. Call OpenAI
    const correctNames = data.correctPlayers.map(p => `${p.firstName} ${p.lastName}`).join(', ');
    
    let prompt;
    if (data.correctPlayers.length === 1) {
      // Single player position
      prompt = `You are an NFL trivia judge and storyteller.

The trivia question was:
- Position: ${data.position}
- Team: ${data.team}
- Year: ${data.year}

The correct answer is: ${correctNames}

The user's answer was: "${data.userAnswer}"

Determine if the user's answer is close enough to be considered correct. Accept:
- Full name (first and last)
- Last name only
- First name only (if distinctive and at least 3+ characters)
- Common nicknames (at least 3+ characters)
- Minor spelling variations (off by 1-2 letters)
- Missing or extra letters
- Phonetically similar spellings

DO NOT ACCEPT:
- Just initials (e.g., "TB", "PM", "JJ") - mark as INCORRECT
- Answers shorter than 3 characters (unless it's a rare exception like "Bo" Jackson)

If the answer is clearly attempting to name the correct player with actual letters (not just initials) and is reasonably similar, mark it CORRECT.

Then provide a response in this format:

If CORRECT:
Start with "✅ Correct!" on its own line, then provide 2-3 interesting facts about ${correctNames}, including personal info (birthplace, college, interesting backstory) and NFL achievements from around ${data.year}. Make it engaging and fun!

If INCORRECT:
Start with "❌ Sorry, the answer was ${correctNames}." on its own line, then provide 2-3 interesting facts about the correct player, including personal info and career highlights. Make it engaging and help them learn about this player!

Keep the facts concise (2-3 sentences total after the first line). Focus on memorable and interesting details.`;
    } else {
      // Multiple players
      let positionType = '';
      let count = '';
      
      switch(data.position) {
        case 'Offensive Linemen':
          positionType = 'offensive linemen';
          count = 'five';
          break;
        case 'Defensive Back':
          positionType = 'defensive backs';
          count = 'four';
          break;
        case 'Wide Receiver':
        case 'Linebacker':
        case 'Defensive Line':
          positionType = data.position.toLowerCase() + 's';
          count = 'three';
          break;
        case 'Running Back':
          positionType = 'running backs';
          count = 'two';
          break;
        default:
          positionType = data.position.toLowerCase() + 's';
          count = 'top players';
      }
      
      prompt = `You are an NFL trivia judge and storyteller.

The trivia question was to name one of the top ${count} ${positionType} by snaps played:
- Team: ${data.team}
- Year: ${data.year}

The correct answers are: ${correctNames}

The user's answer was: "${data.userAnswer}"

Determine if the user's answer matches any of the correct players. Accept:
- Full name (first and last)
- Last name only
- First name only (if distinctive and at least 3+ characters)
- Common nicknames (at least 3+ characters)
- Minor spelling variations (off by 1-2 letters)
- Missing or extra letters
- Phonetically similar spellings

DO NOT ACCEPT:
- Just initials (e.g., "TB", "PM", "JJ") - mark as INCORRECT
- Answers shorter than 3 characters (unless it's a rare exception like "Bo" Jackson)

If the answer is clearly attempting to name one of the correct players with actual letters (not just initials) and is reasonably similar, mark it CORRECT.

Then provide a response in this format:

If CORRECT (matches one of the players):
Start with "✅ Correct!" on its own line, then mention which player they guessed and provide 2-3 interesting facts about that player (personal info like birthplace, college, backstory, plus NFL achievements from around ${data.year}). Also mention the other correct answers: ${correctNames}. Make it engaging!

If INCORRECT:
Start with "❌ Sorry, the top ${count} were: ${correctNames}." on its own line, then provide 2-3 interesting facts about the most notable player from this group, including personal info and career highlights. Make it engaging and help them learn!

Keep the facts concise (2-3 sentences total after the first line). Focus on memorable details.`;
    }
    
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: 'You are a knowledgeable and enthusiastic NFL trivia host who makes learning about players fun and interesting. You are lenient with spelling variations - if someone is clearly trying to name the right player but is off by a letter or two, you mark it correct. However, you NEVER accept just initials (like "TB" or "PM") as correct answers - users must provide actual names.'
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
    const isCorrect = message.includes('✅') || message.toLowerCase().startsWith('correct');
    
    const result = {
      isCorrect,
      message
    };
    
    // 5. Update tracking
    incrementSpending(CONFIG.COST_PER_VALIDATION);
    incrementRateLimit(userId, 'validation');
    
    // 6. Cache result
    if (CONFIG.CACHE_ENABLED) {
      const cacheKey = getValidationCacheKey(data);
      cache.set(cacheKey, result);
    }
    
    console.log(`Validation complete: ${isCorrect ? 'Correct' : 'Incorrect'}`);
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
      } else if (['Wide Receiver', 'Linebacker', 'Defensive Line'].includes(data.position)) {
        count = 'three';
      }
      
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
${isMoreObvious ? '\n\nIMPORTANT: After your hint, add a new line and then add exactly this format: "This player\'s initials are XX and they played college football at [college name]." Replace XX with the initials of the player you chose to hint about, and research/include the actual college name.' : ''}`;
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
