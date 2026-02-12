const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const { createClient } = require('@supabase/supabase-js');
const cron = require('node-cron');

// ─── Supabase client (service role key bypasses RLS) ────────────────────────
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// ─── Config ─────────────────────────────────────────────────────────────────
const TARGET_ONLINE_BOTS = 15;  // How many bots should be "online" at once
const MIN_ONLINE_BOTS = 15;
const MAX_ONLINE_BOTS = 15;
const MAX_CHURN_PER_TICK = 1;   // Don't change more than this many bots per tick

// Simulation config
const SIMULATION_CHANCE = 0.25; // 25% chance per tick to run a simulated game
const GAMES_PER_SIMULATION = 1; // How many games to simulate at once

// Prevent overlapping ticks
let isRunning = false;
let isSimulating = false;

// Track bot difficulty assignments: { botId: 'easy' | 'medium' | ... }
const botDifficulties = {};

// Difficulty distribution for realism
const DIFFICULTY_WEIGHTS = [
  { name: 'beginner', weight: 10 },
  { name: 'easy',     weight: 25 },
  { name: 'medium',   weight: 35 },
  { name: 'hard',     weight: 20 },
  { name: 'expert',   weight: 10 },
];

// Win probability by difficulty (higher = more likely to win)
const DIFFICULTY_STRENGTH = {
  beginner: 0.2,
  easy: 0.35,
  medium: 0.5,
  hard: 0.7,
  expert: 0.85,
};

function pickDifficulty() {
  const total = DIFFICULTY_WEIGHTS.reduce((s, d) => s + d.weight, 0);
  let r = Math.random() * total;
  for (const d of DIFFICULTY_WEIGHTS) {
    r -= d.weight;
    if (r <= 0) return d.name;
  }
  return 'medium';
}

function getBotDifficulty(botId) {
  if (!botDifficulties[botId]) {
    botDifficulties[botId] = pickDifficulty();
  }
  return botDifficulties[botId];
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
function log(msg) {
  console.log(`[${new Date().toISOString()}] ${msg}`);
}

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// ─── Ensure a bot has a leaderboard row (upsert to avoid duplicates) ────────
async function ensureLeaderboard(bot) {
  // Check if already exists
  const { data } = await supabase
    .from('leaderboard')
    .select('id')
    .eq('id', bot.id)
    .maybeSingle();

  if (data) return true;

  const score = 40 + Math.random() * 30;
  const games = randomInt(3, 22);
  const wins = Math.floor(games * (0.3 + Math.random() * 0.4));
  const losses = Math.floor((games - wins) * 0.7);
  const draws = games - wins - losses;

  const { error } = await supabase.from('leaderboard').insert({
    id: bot.id,
    username: bot.username || 'Bot',
    online_score: parseFloat(score.toFixed(1)),
    online_games: games,
    offline_score: 0,
    offline_games: 0,
    score: 50,
    avg_score: 50,
    games_played: games,
    wins,
    losses,
    draws,
  });

  if (error && !error.message.includes('duplicate')) {
    log(`  Error creating leaderboard for ${bot.username}: ${error.message}`);
    return false;
  }
  return true;
}

// ─── Mark a bot as online ───────────────────────────────────────────────────
async function setBotOnline(botId) {
  await supabase.from('profiles').update({ is_online: true }).eq('id', botId);
}

// ─── Mark a bot as offline ──────────────────────────────────────────────────
async function setBotOffline(botId) {
  await supabase.from('profiles').update({ is_online: false }).eq('id', botId);
}

// ─── Main tick: manage which bots are online ────────────────────────────────
async function tick() {
  if (isRunning) return;
  isRunning = true;

  try {
    log('--- Bot manager tick ---');

    // 1. Get currently online bots
    const { data: onlineBots } = await supabase
      .from('profiles')
      .select('id, username')
      .eq('is_bot', true)
      .eq('is_online', true);

    const currentOnline = onlineBots || [];
    log(`Currently online: ${currentOnline.length} bots`);

    // 2. Decide how many we want online (vary slightly for realism)
    const target = randomInt(MIN_ONLINE_BOTS, MAX_ONLINE_BOTS);

    // 3. If we need more bots online, pick random offline bots (limit churn)
    if (currentOnline.length < target) {
      const needed = Math.min(target - currentOnline.length, MAX_CHURN_PER_TICK);

      // Get offline bots
      const { data: offlineBots } = await supabase
        .from('profiles')
        .select('id, username')
        .eq('is_bot', true)
        .eq('is_online', false)
        .limit(needed * 2);

      if (offlineBots && offlineBots.length > 0) {
        const shuffled = offlineBots.sort(() => Math.random() - 0.5);
        const toActivate = shuffled.slice(0, needed);

        for (const bot of toActivate) {
          await setBotOnline(bot.id);
          await ensureLeaderboard(bot);
          log(`  Brought ${bot.username} online`);
        }
      }
    }

    // 4. If too many bots online, take some offline (limit churn)
    if (currentOnline.length > target) {
      const rawExcess = currentOnline.length - target;
      const excess = Math.min(rawExcess, MAX_CHURN_PER_TICK);
      const toDeactivate = currentOnline
        .sort(() => Math.random() - 0.5)
        .slice(0, excess);

      for (const bot of toDeactivate) {
        await setBotOffline(bot.id);
        log(`  Took ${bot.username} offline`);
      }
    }

    // 5. Ensure all online bots have leaderboard entries
    const { data: stillOnline } = await supabase
      .from('profiles')
      .select('id, username')
      .eq('is_bot', true)
      .eq('is_online', true);

    for (const bot of (stillOnline || [])) {
      await ensureLeaderboard(bot);
    }

    log(`--- Tick complete (${(stillOnline || []).length} bots online) ---\n`);
  } catch (err) {
    log(`Tick error: ${err.message}`);
  } finally {
    isRunning = false;
  }
}

// ─── Simulate a bot-vs-bot game (just update leaderboards, no actual moves) ─
async function simulateGame(bot1, bot2) {
  const diff1 = getBotDifficulty(bot1.id);
  const diff2 = getBotDifficulty(bot2.id);
  
  const strength1 = DIFFICULTY_STRENGTH[diff1] || 0.5;
  const strength2 = DIFFICULTY_STRENGTH[diff2] || 0.5;
  
  // Determine winner based on relative strength + randomness
  const total = strength1 + strength2;
  const bot1WinChance = strength1 / total;
  
  // 10% chance of draw
  const roll = Math.random();
  let winnerId, loserId, isDraw;
  
  if (roll < 0.1) {
    isDraw = true;
    winnerId = null;
    loserId = null;
    log(`  Simulated: ${bot1.username} (${diff1}) vs ${bot2.username} (${diff2}) → DRAW`);
  } else if (roll < 0.1 + (0.9 * bot1WinChance)) {
    isDraw = false;
    winnerId = bot1.id;
    loserId = bot2.id;
    log(`  Simulated: ${bot1.username} (${diff1}) vs ${bot2.username} (${diff2}) → ${bot1.username} wins`);
  } else {
    isDraw = false;
    winnerId = bot2.id;
    loserId = bot1.id;
    log(`  Simulated: ${bot1.username} (${diff1}) vs ${bot2.username} (${diff2}) → ${bot2.username} wins`);
  }
  
  await updateBotLeaderboard(winnerId, loserId, isDraw, bot1.id, bot2.id);
}

// ─── Run simulated games between random pairs of online bots ────────────────
async function runSimulations() {
  if (isSimulating) return;
  
  // Random chance to skip this tick
  if (Math.random() > SIMULATION_CHANCE) return;
  
  isSimulating = true;

  try {
    // Get all online bots
    const { data: onlineBots } = await supabase
      .from('profiles')
      .select('id, username')
      .eq('is_bot', true)
      .eq('is_online', true);

    if (!onlineBots || onlineBots.length < 2) return;

    // Shuffle and pick pairs
    const shuffled = onlineBots.sort(() => Math.random() - 0.5);
    
    for (let i = 0; i < GAMES_PER_SIMULATION && i * 2 + 1 < shuffled.length; i++) {
      const bot1 = shuffled[i * 2];
      const bot2 = shuffled[i * 2 + 1];
      await simulateGame(bot1, bot2);
    }
  } catch (err) {
    log(`Simulation error: ${err.message}`);
  } finally {
    isSimulating = false;
  }
}

// ─── Update leaderboard stats after simulated game ──────────────────────────
async function updateBotLeaderboard(winnerId, loserId, isDraw, bot1Id, bot2Id) {
  try {
    if (isDraw) {
      // Both get a draw
      for (const botId of [bot1Id, bot2Id]) {
        const { data: entry } = await supabase
          .from('leaderboard')
          .select('*')
          .eq('id', botId)
          .maybeSingle();

        if (entry) {
          const newGames = (entry.online_games || 0) + 1;
          const newDraws = (entry.draws || 0) + 1;
          // ELO for draw: expected score calculation
          const opponentRating = 50; // Draw scenario - assume equal opponent
          const expectedScore = 1.0 / (1.0 + Math.pow(10, (opponentRating - (entry.avg_score || 50)) / 25));
          const actualScore = 0.5; // Draw
          const kFactor = 3.2; // Scaled K factor for 0-100 range
          const ratingChange = kFactor * (actualScore - expectedScore);
          const newAvgScore = Math.max(0, Math.min(100, (entry.avg_score || 50) + ratingChange));

          await supabase
            .from('leaderboard')
            .update({
              online_games: newGames,
              games_played: newGames,
              draws: newDraws,
              avg_score: parseFloat(newAvgScore.toFixed(1)),
              score: Math.round(newAvgScore), // legacy column
            })
            .eq('id', botId);
        }
      }
    } else if (winnerId && loserId) {
      // Winner gains rating, loser loses rating (ELO system)
      const { data: winnerEntry } = await supabase
        .from('leaderboard')
        .select('*')
        .eq('id', winnerId)
        .maybeSingle();

      const { data: loserEntry } = await supabase
        .from('leaderboard')
        .select('*')
        .eq('id', loserId)
        .maybeSingle();

      if (winnerEntry) {
        const newGames = (winnerEntry.online_games || 0) + 1;
        const newWins = (winnerEntry.wins || 0) + 1;
        
        // ELO calculation for winner
        const winnerRating = winnerEntry.avg_score || 50;
        const loserRating = loserEntry?.avg_score || 50;
        const expectedScore = 1.0 / (1.0 + Math.pow(10, (loserRating - winnerRating) / 25));
        const kFactor = 3.2; // Scaled K factor for 0-100 range
        const ratingChange = kFactor * (1.0 - expectedScore); // actualScore = 1 for win
        const newAvgScore = Math.min(100, winnerRating + ratingChange);

        await supabase
          .from('leaderboard')
          .update({
            online_games: newGames,
            games_played: newGames,
            wins: newWins,
            avg_score: parseFloat(newAvgScore.toFixed(1)),
            score: Math.round(newAvgScore), // legacy column
          })
          .eq('id', winnerId);
      }

      if (loserEntry) {
        const newGames = (loserEntry.online_games || 0) + 1;
        const newLosses = (loserEntry.losses || 0) + 1;
        
        // ELO calculation for loser
        const loserRating = loserEntry.avg_score || 50;
        const winnerRating = winnerEntry?.avg_score || 50;
        const expectedScore = 1.0 / (1.0 + Math.pow(10, (winnerRating - loserRating) / 25));
        const kFactor = 3.2; // Scaled K factor for 0-100 range
        const ratingChange = kFactor * (0.0 - expectedScore); // actualScore = 0 for loss
        const newAvgScore = Math.max(0, loserRating + ratingChange);

        await supabase
          .from('leaderboard')
          .update({
            online_games: newGames,
            games_played: newGames,
            losses: newLosses,
            avg_score: parseFloat(newAvgScore.toFixed(1)),
            score: Math.round(newAvgScore), // legacy column
          })
          .eq('id', loserId);
      }
    }
  } catch (err) {
    log(`Error updating bot leaderboard: ${err.message}`);
  }
}

// ─── Schedule ───────────────────────────────────────────────────────────────
// Bot online/offline management: run every 5 minutes
cron.schedule('*/5 * * * *', tick);

// Simulated games: run every 5 minutes (25% chance each time)
setInterval(runSimulations, 300000);

// Run once at startup
log('Bot manager starting (simulation mode)...');
log(`Config: MIN=${MIN_ONLINE_BOTS}, MAX=${MAX_ONLINE_BOTS}, CHURN_LIMIT=${MAX_CHURN_PER_TICK}`);
log(`Simulation: ${SIMULATION_CHANCE * 100}% chance per tick, ${GAMES_PER_SIMULATION} games per simulation`);
log('Difficulty distribution: ' + DIFFICULTY_WEIGHTS.map(d => `${d.name}(${d.weight}%)`).join(', '));
tick();
