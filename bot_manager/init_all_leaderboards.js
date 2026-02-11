/**
 * Initialize leaderboard entries for ALL bots at once.
 * Run this once to populate the leaderboard with all 1000 bots.
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

async function initAllLeaderboards() {
  console.log('Fetching all bots...');
  
  // Get all bots from profiles
  const { data: bots, error: botsErr } = await supabase
    .from('profiles')
    .select('id, username')
    .eq('is_bot', true);

  if (botsErr) {
    console.error('Error fetching bots:', botsErr.message);
    return;
  }

  console.log(`Found ${bots.length} bots`);

  // Get existing leaderboard entries
  const { data: existing } = await supabase
    .from('leaderboard')
    .select('id');

  const existingIds = new Set((existing || []).map(e => e.id));
  console.log(`${existingIds.size} already have leaderboard entries`);

  // Filter to bots that need entries
  const needsEntry = bots.filter(b => !existingIds.has(b.id));
  console.log(`Creating entries for ${needsEntry.length} bots...`);

  let created = 0;
  let failed = 0;

  // Process in batches of 50
  for (let i = 0; i < needsEntry.length; i += 50) {
    const batch = needsEntry.slice(i, i + 50);
    const entries = batch.map(bot => {
      const score = 40 + Math.random() * 30;
      const games = randomInt(3, 22);
      const wins = Math.floor(games * (0.3 + Math.random() * 0.4));
      const losses = Math.floor((games - wins) * 0.7);
      const draws = games - wins - losses;

      return {
        id: bot.id,
        username: bot.username || 'Bot',
        online_score: parseFloat(score.toFixed(1)),
        online_games: games,
        offline_score: 0,
        offline_games: 0,
        score: 0,
        avg_score: 0,
        games_played: games,
        wins,
        losses,
        draws,
      };
    });

    const { error } = await supabase.from('leaderboard').insert(entries);
    if (error) {
      console.error(`Batch ${i / 50 + 1} failed:`, error.message);
      failed += batch.length;
    } else {
      created += batch.length;
      console.log(`Created ${created}/${needsEntry.length}...`);
    }
  }

  console.log(`\nDone! Created ${created} entries, ${failed} failed.`);
  console.log(`Total leaderboard entries: ${existingIds.size + created}`);
}

initAllLeaderboards();
