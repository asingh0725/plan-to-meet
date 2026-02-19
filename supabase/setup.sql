-- ============================================================
-- PlanToMeet — Full Database Setup
-- Run this file once in the Supabase SQL editor to apply all
-- schema changes in the correct order.
-- ============================================================

-- 1. Core tables (assumed already created via Supabase dashboard):
--    polls, time_slots, responses, participants, availability_blocks
--    If starting fresh, create them before running this file.

-- 2. RLS policies
-- (copy/paste content of rls_policies.sql here, or run that file first)

-- 3. Poll retention / cleanup
\i poll_retention.sql

-- 4. Push tokens (for APNs notifications)
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS push_tokens (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id  text        NOT NULL,
  token       text        NOT NULL,
  platform    text        NOT NULL DEFAULT 'ios',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, token)
);

ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "push_tokens_insert" ON push_tokens
  FOR INSERT WITH CHECK (true);

CREATE POLICY "push_tokens_update" ON push_tokens
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE OR REPLACE FUNCTION update_push_tokens_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER push_tokens_updated_at
  BEFORE UPDATE ON push_tokens
  FOR EACH ROW EXECUTE FUNCTION update_push_tokens_updated_at();

-- 5. Reactions (emoji + comment on finalized polls)
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS reactions (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id     text        NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  session_id  text        NOT NULL,
  emoji       text        NOT NULL,
  comment     text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (poll_id, session_id)
);

ALTER TABLE reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reactions_select_all" ON reactions
  FOR SELECT USING (true);

CREATE POLICY "reactions_insert" ON reactions
  FOR INSERT WITH CHECK (true);

CREATE POLICY "reactions_update_self" ON reactions
  FOR UPDATE
  USING (session_id = (current_setting('request.jwt.claims', true)::jsonb ->> 'session_id'))
  WITH CHECK (session_id = (current_setting('request.jwt.claims', true)::jsonb ->> 'session_id'));

-- 6. Recurring polls (parent_poll_id)
-- ----------------------------------------
ALTER TABLE polls
  ADD COLUMN IF NOT EXISTS parent_poll_id uuid REFERENCES polls(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS polls_parent_poll_id_idx ON polls(parent_poll_id)
  WHERE parent_poll_id IS NOT NULL;
