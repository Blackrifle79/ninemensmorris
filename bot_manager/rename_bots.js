// One-time script: Rename all bot profiles to realistic gamer-style usernames
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Generate a realistic username
const adjectives = [
  'Swift', 'Dark', 'Iron', 'Storm', 'Frost', 'Shadow', 'Blaze', 'Crimson',
  'Silver', 'Golden', 'Raven', 'Wolf', 'Ember', 'Mystic', 'Thunder',
  'Silent', 'Steel', 'Brave', 'Stone', 'Wild', 'Noble', 'Wicked', 'Ancient',
  'Clever', 'Mighty', 'Dread', 'Night', 'Star', 'Grim', 'Red', 'Blue',
  'Lunar', 'Solar', 'Copper', 'Ashen', 'Pale', 'Cold', 'Keen', 'Dire',
  'Grand', 'Dusk', 'Dawn', 'True', 'Mad', 'Old', 'Tall', 'Sly', 'Bold',
  'Lucky', 'Rusty', 'Gray', 'Oak', 'Jade', 'Onyx', 'Ivory', 'Cobalt',
];

const nouns = [
  'Knight', 'Falcon', 'Bear', 'Fox', 'Hawk', 'Drake', 'Sage', 'Rook',
  'Pawn', 'Bishop', 'Viper', 'Eagle', 'Tiger', 'Lion', 'Lynx', 'Owl',
  'Phoenix', 'Sparrow', 'Crow', 'Hound', 'Stag', 'Boar', 'Ram', 'Otter',
  'Badger', 'Bison', 'Crane', 'Serpent', 'Panther', 'Jaguar', 'Coyote',
  'Moose', 'Elk', 'Moth', 'Beetle', 'Spider', 'Mantis', 'Hornet',
  'Miller', 'Mason', 'Smith', 'Walker', 'Hunter', 'Fisher', 'Archer',
  'Ranger', 'Guard', 'Scout', 'Rider', 'Warden', 'Dueler', 'Keeper',
  'Forge', 'Blade', 'Shield', 'Hammer', 'Arrow', 'Flint', 'Thorn',
];

const usedNames = new Set();

function generateUsername() {
  for (let i = 0; i < 100; i++) {
    const adj = adjectives[Math.floor(Math.random() * adjectives.length)];
    const noun = nouns[Math.floor(Math.random() * nouns.length)];
    const num = Math.random() < 0.7 ? Math.floor(Math.random() * 999) + 1 : '';
    // Mix formats for variety
    const formats = [
      `${adj}${noun}${num}`,
      `${adj}_${noun}${num}`,
      `${adj.toLowerCase()}${noun}${num}`,
      `${noun}${adj}${num}`,
      `${adj}${noun.toLowerCase()}${num}`,
    ];
    const name = formats[Math.floor(Math.random() * formats.length)];
    if (!usedNames.has(name) && name.length <= 20) {
      usedNames.add(name);
      return name;
    }
  }
  return `Player${Date.now() % 100000}`;
}

async function main() {
  // Get all bot profiles
  let allBots = [];
  let offset = 0;
  const batchSize = 500;

  while (true) {
    const { data, error } = await supabase
      .from('profiles')
      .select('id, username')
      .eq('is_bot', true)
      .range(offset, offset + batchSize - 1);

    if (error) {
      console.log('Error fetching bots:', error.message);
      break;
    }
    if (!data || data.length === 0) break;
    allBots = allBots.concat(data);
    offset += batchSize;
    if (data.length < batchSize) break;
  }

  console.log(`Found ${allBots.length} bots to rename`);

  let renamed = 0;
  let errors = 0;

  for (const bot of allBots) {
    const newName = generateUsername();
    const { error } = await supabase
      .from('profiles')
      .update({ username: newName })
      .eq('id', bot.id);

    if (error) {
      errors++;
      if (errors < 5) console.log(`  Error renaming ${bot.username}: ${error.message}`);
    } else {
      renamed++;
    }

    if (renamed % 100 === 0 && renamed > 0) {
      console.log(`  Renamed ${renamed}/${allBots.length}...`);
    }
  }

  console.log(`Done! Renamed ${renamed} bots, ${errors} errors`);

  // Also update leaderboard usernames
  console.log('Updating leaderboard usernames...');
  const { data: updatedBots } = await supabase
    .from('profiles')
    .select('id, username')
    .eq('is_bot', true)
    .limit(1000);

  let lbUpdated = 0;
  for (const bot of (updatedBots || [])) {
    const { error } = await supabase
      .from('leaderboard')
      .update({ username: bot.username })
      .eq('id', bot.id);
    if (!error) lbUpdated++;
  }
  console.log(`Updated ${lbUpdated} leaderboard entries`);

  // Also update any waiting room host_username
  console.log('Updating waiting room usernames...');
  let roomsUpdated = 0;
  for (const bot of (updatedBots || [])) {
    const { data } = await supabase
      .from('game_rooms')
      .update({ host_username: bot.username })
      .eq('host_id', bot.id)
      .eq('status', 'waiting')
      .select('id');
    if (data) roomsUpdated += data.length;
  }
  console.log(`Updated ${roomsUpdated} waiting rooms`);
}

main().catch(console.error);
