-- Premium poll fields for Event Pass features

ALTER TABLE polls
  ADD COLUMN IF NOT EXISTS is_premium boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS details text,
  ADD COLUMN IF NOT EXISTS closes_at timestamptz;

CREATE INDEX IF NOT EXISTS polls_is_premium_idx
  ON polls(is_premium)
  WHERE is_premium = true;

CREATE INDEX IF NOT EXISTS polls_closes_at_idx
  ON polls(closes_at)
  WHERE closes_at IS NOT NULL;
