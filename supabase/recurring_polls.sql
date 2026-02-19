-- Recurring polls: add parent_poll_id reference to track cloned polls.
-- Run in Supabase SQL editor.

ALTER TABLE polls
  ADD COLUMN IF NOT EXISTS parent_poll_id uuid REFERENCES polls(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS polls_parent_poll_id_idx ON polls(parent_poll_id)
  WHERE parent_poll_id IS NOT NULL;
