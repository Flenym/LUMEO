-- Lumeo 003_seed.sql — PostgreSQL, beta seed data.
-- Run: psql $DATABASE_URL -f migrations/003_seed.sql (after 001 + 002)
-- Idempotent: all inserts use ON CONFLICT DO NOTHING.
-- Column names match 001_init.sql exactly.

-- 1. Starter game catalog (19 titles from spec). Game(id, title, is_custom).
INSERT INTO Game (title, is_custom) VALUES
  ('Fortnite', FALSE),
  ('Minecraft', FALSE),
  ('Valorant', FALSE),
  ('Counter-Strike 2', FALSE),
  ('Roblox', FALSE),
  ('Apex Legends', FALSE),
  ('Call of Duty', FALSE),
  ('GTA', FALSE),
  ('Rocket League', FALSE),
  ('Overwatch', FALSE),
  ('PUBG', FALSE),
  ('Terraria', FALSE),
  ('Sea of Thieves', FALSE),
  ('Rainbow Six Siege', FALSE),
  ('Destiny 2', FALSE),
  ('The Finals', FALSE),
  ('Fall Guys', FALSE),
  ('Among Us', FALSE),
  ('EA Sports FC', FALSE)
ON CONFLICT DO NOTHING;

-- 2. Official theme catalog (8). Mirrors Design/theme.json.
INSERT INTO ThemeCatalog (name, accent) VALUES
  ('OLED Orange', '#FF6B00'),
  ('Purple', '#AF52DE'),
  ('Blue', '#0A84FF'),
  ('Cyan', '#64D2FF'),
  ('Green', '#30D158'),
  ('Yellow', '#FFD60A'),
  ('Red', '#FF453A'),
  ('Pink', '#FF375F')
ON CONFLICT DO NOTHING;

-- 3. Rank thresholds Wood..Legend (spec XP table).
INSERT INTO RankThreshold (name, min_xp) VALUES
  ('Wood', 0),
  ('Stone', 100),
  ('Iron', 250),
  ('Bronze', 500),
  ('Silver', 1000),
  ('Gold', 2000),
  ('Platinum', 3500),
  ('Diamond', 5500),
  ('Master', 8000),
  ('Grandmaster', 12000),
  ('Legend', 18000)
ON CONFLICT DO NOTHING;

-- 4. Achievements (6). Achievement(id, code, title, xp).
INSERT INTO Achievement (code, title, xp) VALUES
  ('first-session', 'First Session', 30),
  ('squad-born', 'Squad Born', 15),
  ('week-streak', '7-Day Streak', 50),
  ('workshop-first', 'First Workshop Publish', 25),
  ('social-five', '5 Friends', 20),
  ('marathon', '10 Sessions', 80)
ON CONFLICT DO NOTHING;

-- 5. Product feature flags (FeatureFlag(key PK, enabled)).
-- 001 already seeds workshop_enabled/gifts_enabled/e2ee_enforced.
INSERT INTO FeatureFlag (key, enabled) VALUES
  ('public_player_search', FALSE),
  ('discord_login', FALSE),
  ('apple_login', FALSE),
  ('google_login', FALSE),
  ('phone_auth', FALSE),
  ('premium', FALSE),
  ('workshop_marketplace', FALSE),
  ('currency_purchases', FALSE),
  ('trading', FALSE),
  ('public_profiles', FALSE),
  ('live_activities', TRUE),
  ('widgets', TRUE)
ON CONFLICT (key) DO NOTHING;
