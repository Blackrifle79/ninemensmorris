// Script to create bot profiles in the database
// Run with: node create_bots.js [count]
// Example: node create_bots.js 50

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const { createClient } = require('@supabase/supabase-js');
const { v4: uuidv4 } = require('uuid');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Username generation (same as rename_bots.js)
const adjectives = [
  'Swift', 'Dark', 'Iron', 'Storm', 'Frost', 'Shadow', 'Blaze', 'Crimson',
  'Silver', 'Golden', 'Raven', 'Wolf', 'Ember', 'Mystic', 'Thunder',
  'Silent', 'Steel', 'Brave', 'Stone', 'Wild', 'Noble', 'Wicked', 'Ancient',
  'Clever', 'Mighty', 'Dread', 'Night', 'Star', 'Grim', 'Red', 'Blue',
  'Lunar', 'Solar', 'Copper', 'Ashen', 'Pale', 'Cold', 'Keen', 'Dire',
  'Grand', 'Dusk', 'Dawn', 'True', 'Mad', 'Old', 'Tall', 'Sly', 'Bold',
  'Lucky', 'Rusty', 'Gray', 'Oak', 'Jade', 'Onyx', 'Ivory', 'Cobalt',
  'Quick', 'Brave', 'Fury', 'Rapid', 'Flash', 'Sharp', 'Fierce', 'Prime',
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
  'Striker', 'Champ', 'Master', 'Legend', 'Ace', 'Pro', 'King', 'Baron',
];

const usedNames = new Set();

function generateUsername() {
  for (let i = 0; i < 100; i++) {
    const adj = adjectives[Math.floor(Math.random() * adjectives.length)];
    const noun = nouns[Math.floor(Math.random() * nouns.length)];
    const num = Math.random() < 0.7 ? Math.floor(Math.random() * 999) + 1 : '';
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
  const targetCount = parseInt(process.argv[2]) || 50;
  
  // First, check how many bots already exist
  const { data: existingBots, error: countErr } = await supabase
    .from('profiles')
    .select('id, username')
    .eq('is_bot', true);
  
  if (countErr) {
    console.log('Error checking existing bots:', countErr.message);
    return;
  }
  
  const existingCount = existingBots?.length || 0;
  console.log(`Found ${existingCount} existing bots`);
  
  // Add existing names to used set
  for (const bot of (existingBots || [])) {
    usedNames.add(bot.username);
  }
  
  const toCreate = Math.max(0, targetCount - existingCount);
  if (toCreate === 0) {
    console.log(`Already have ${existingCount} bots, target is ${targetCount}. No new bots needed.`);
    return;
  }
  
  console.log(`Creating ${toCreate} new bots to reach target of ${targetCount}...`);
  
  let created = 0;
  let errors = 0;
  
  for (let i = 0; i < toCreate; i++) {
    const botId = uuidv4();
    const username = generateUsername();
    
    // Insert into profiles table
    const { error: profileErr } = await supabase
      .from('profiles')
      .insert({
        id: botId,
        username: username,
        is_bot: true,
        is_online: false,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });
    
    if (profileErr) {
      errors++;
      if (errors <= 5) {
        console.log(`  Error creating bot ${username}: ${profileErr.message}`);
      }
      continue;
    }
    
    // Create leaderboard entry with varied stats
    const score = 35 + Math.random() * 35;
    const games = Math.floor(5 + Math.random() * 30);
    const wins = Math.floor(games * (0.25 + Math.random() * 0.5));
    const losses = Math.floor((games - wins) * 0.7);
    const draws = games - wins - losses;
    
    await supabase.from('leaderboard').insert({
      id: botId,
      username: username,
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
    });
    
    created++;
    if (created % 10 === 0) {
      console.log(`  Created ${created}/${toCreate} bots...`);
    }
  }
  
  console.log(`\nDone! Created ${created} bots (${errors} errors)`);
  console.log(`Total bots now: ${existingCount + created}`);
}

main().catch(console.error);
