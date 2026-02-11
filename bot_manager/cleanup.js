// One-time cleanup: batch delete all bot game rooms and leaderboard entries
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function cleanup() {
  console.log('Cleaning up bot data...');

  // 1. Get all bot IDs
  const { data: bots, error: botErr } = await supabase
    .from('profiles')
    .select('id')
    .eq('is_bot', true);

  if (botErr) {
    console.error('Error fetching bots:', botErr.message);
    return;
  }

  const botIds = bots.map(b => b.id);
  console.log(`Found ${botIds.length} bots`);

  // 2. Batch delete game rooms in chunks of 50
  let batch = 0;
  const totalBatches = Math.ceil(botIds.length / 50);
  for (let i = 0; i < botIds.length; i += 50) {
    const chunk = botIds.slice(i, i + 50);
    const { error } = await supabase
      .from('game_rooms')
      .delete()
      .in('host_id', chunk);
    batch++;
    if (error) {
      console.error(`Error deleting rooms batch ${batch}:`, error.message);
    } else {
      console.log(`  Deleted rooms batch ${batch}/${totalBatches}`);
    }
  }
  console.log('  Room cleanup done');

  // 3. Batch delete leaderboard entries in chunks of 50
  batch = 0;
  for (let i = 0; i < botIds.length; i += 50) {
    const chunk = botIds.slice(i, i + 50);
    const { error } = await supabase
      .from('leaderboard')
      .delete()
      .in('id', chunk);
    batch++;
    if (error) {
      console.error(`Error deleting leaderboard batch ${batch}:`, error.message);
    } else {
      console.log(`  Deleted leaderboard batch ${batch}/${totalBatches}`);
    }
  }
  console.log('  Leaderboard cleanup done');

  // 4. Set all bots to offline
  for (let i = 0; i < botIds.length; i += 50) {
    const chunk = botIds.slice(i, i + 50);
    await supabase
      .from('profiles')
      .update({ is_online: false })
      .in('id', chunk);
  }
  console.log('  Set all bots to offline');

  console.log('Cleanup complete!');
}

cleanup();
