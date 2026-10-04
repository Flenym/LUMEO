-- Lumeo 002_constraints.sql — PostgreSQL, beta.
-- Run: psql $DATABASE_URL -f migrations/002_constraints.sql (after 001_init.sql)
-- All statements idempotent (IF NOT EXISTS / DO blocks).
-- NOTE: 001 already contains CHECKs for CurrencyTransaction.amount,
-- WorkshopItem.state and GameSession.state — they are NOT duplicated here.

-- 1. Case-insensitive uniqueness for nicknames.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'user_nickname_lower_uidx') THEN
    CREATE UNIQUE INDEX user_nickname_lower_uidx ON "User" (lower(nickname));
  END IF;
END $$;

-- 2. Squad size guard: max 200 members enforced by trigger (count check).
CREATE OR REPLACE FUNCTION squad_member_limit_guard() RETURNS trigger AS $$
DECLARE
  cnt INTEGER;
BEGIN
  SELECT count(*) INTO cnt FROM SquadMember WHERE squad_id = NEW.squad_id;
  IF cnt >= 200 THEN
    RAISE EXCEPTION 'SQUAD_FULL: squad % already has 200 members', NEW.squad_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS squad_member_limit_trg ON SquadMember;
CREATE TRIGGER squad_member_limit_trg
  BEFORE INSERT ON SquadMember
  FOR EACH ROW EXECUTE FUNCTION squad_member_limit_guard();

-- 3. Friend request lookups (pending checks + decline-cooldown scans).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'friendrequest_pair_status_idx') THEN
    CREATE INDEX friendrequest_pair_status_idx ON FriendRequest (from_user_id, to_user_id, status);
  END IF;
END $$;

-- 4. Hot-path indexes (guarded; 001 already ships idx_report_cluster).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'status_user_idx') THEN
    CREATE INDEX status_user_idx ON Status (user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'gamesession_state_idx') THEN
    CREATE INDEX gamesession_state_idx ON GameSession (state);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'gamesessionparticipant_session_idx') THEN
    CREATE INDEX gamesessionparticipant_session_idx ON GameSessionParticipant (session_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'squadmember_squad_idx') THEN
    CREATE INDEX squadmember_squad_idx ON SquadMember (squad_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'notification_user_idx') THEN
    CREATE INDEX notification_user_idx ON Notification (user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_report_cluster') THEN
    CREATE INDEX idx_report_cluster ON Report (report_cluster_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'messagemetadata_conversation_idx') THEN
    CREATE INDEX messagemetadata_conversation_idx ON MessageMetadata (conversation_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'auditlog_actor_idx') THEN
    CREATE INDEX auditlog_actor_idx ON AuditLog (actor_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'usergame_user_idx') THEN
    CREATE INDEX usergame_user_idx ON UserGame (user_id);
  END IF;
END $$;

-- 5. Seed-support catalogs (mirrors of Shared constants + Design/theme.json).
-- 001 models ProfileTheme per-profile and Rank per-user, so official theme
-- and rank-threshold catalogs live here for 003_seed.sql.
CREATE TABLE IF NOT EXISTS ThemeCatalog (
  name TEXT PRIMARY KEY,
  accent TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS RankThreshold (
  name TEXT PRIMARY KEY,
  min_xp INTEGER NOT NULL CHECK (min_xp >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
