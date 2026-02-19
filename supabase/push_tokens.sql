-- Push tokens table for APNs notifications.
-- Run in Supabase SQL editor.

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

-- Anyone can upsert their own token
CREATE POLICY "push_tokens_insert" ON push_tokens
  FOR INSERT WITH CHECK (true);

CREATE POLICY "push_tokens_update" ON push_tokens
  FOR UPDATE USING (true) WITH CHECK (true);

-- Edge Function reads all tokens (uses service_role key, bypasses RLS)
-- No SELECT policy needed for anon clients

-- Auto-update updated_at on upsert
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
