-- Create a leaderboard table used by the app (run in your Supabase SQL editor)
-- Adjust types/names to match your project's conventions

create table if not exists leaderboard (
  id uuid primary key references auth.users(id),
  username text,
  score integer default 0,
  avg_score double precision default 0,
  games_played integer default 0,
  online_score double precision default 0,
  online_games integer default 0,
  offline_score double precision default 0,
  offline_games integer default 0,
  wins integer default 0,
  losses integer default 0,
  draws integer default 0,
  moves_played integer default 0,
  captures integer default 0,
  updated_at timestamptz default now()
);

-- Migration: add new scoring columns to an existing leaderboard table
-- (safe to run even if columns already exist)
alter table if exists leaderboard add column if not exists avg_score double precision default 0;
alter table if exists leaderboard add column if not exists games_played integer default 0;
alter table if exists leaderboard add column if not exists online_score double precision default 0;
alter table if exists leaderboard add column if not exists online_games integer default 0;
alter table if exists leaderboard add column if not exists offline_score double precision default 0;
alter table if exists leaderboard add column if not exists offline_games integer default 0;
alter table if exists leaderboard add column if not exists draws integer default 0;

-- Add a JSON column to game_rooms to store per-game summaries
alter table if exists game_rooms add column if not exists game_summary jsonb;

-- Migration: Allow bots to join game rooms and be listed on leaderboard
-- Bots exist only in the profiles table, not in auth.users, so we need to
-- drop these foreign key constraints to allow bot-vs-bot games.

-- First, drop the FK constraint on guest_id (allows bots to join rooms)
alter table game_rooms drop constraint if exists game_rooms_guest_id_fkey;

-- Optional: Drop FK on host_id if bots also need to create rooms (they do)
alter table game_rooms drop constraint if exists game_rooms_host_id_fkey;

-- Optional: Drop FK on leaderboard.id to allow bots on the leaderboard
-- (Note: This may already be working via other means)
alter table leaderboard drop constraint if exists leaderboard_id_fkey;
