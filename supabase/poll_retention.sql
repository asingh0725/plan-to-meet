-- Poll data retention and auto-purge for PlanToMeet.
-- Apply in Supabase SQL editor or as part of migrations.

-- Schema additions
ALTER TABLE polls ADD COLUMN IF NOT EXISTS archived_at timestamptz;
ALTER TABLE polls ADD COLUMN IF NOT EXISTS archived_reason text;
ALTER TABLE polls ADD COLUMN IF NOT EXISTS finalized_for_date date;
ALTER TABLE polls ADD COLUMN IF NOT EXISTS range_end_date date;
ALTER TABLE polls ADD COLUMN IF NOT EXISTS participant_count int;
ALTER TABLE polls ADD COLUMN IF NOT EXISTS response_count int;
ALTER TABLE polls ADD COLUMN IF NOT EXISTS time_slot_count int;

CREATE INDEX IF NOT EXISTS polls_archived_at_idx ON polls (archived_at);
CREATE INDEX IF NOT EXISTS polls_status_idx ON polls (status);
CREATE INDEX IF NOT EXISTS polls_finalized_for_date_idx ON polls (finalized_for_date);
CREATE INDEX IF NOT EXISTS polls_range_end_date_idx ON polls (range_end_date);

-- Cleanup function: archive expired polls and purge related data.
CREATE OR REPLACE FUNCTION cleanup_expired_polls()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  rec RECORD;
  v_finalized_date date;
  v_range_end_date date;
  v_participant_count int;
  v_response_count int;
  v_time_slot_count int;
BEGIN
  FOR rec IN
    SELECT
      p.id,
      p.status,
      p.created_at::date AS created_date,
      p.finalized_slot_id,
      ts_final.finalized_date,
      ts_range.range_end_date
    FROM polls p
    LEFT JOIN LATERAL (
      SELECT day::date AS finalized_date
      FROM time_slots
      WHERE id = p.finalized_slot_id
      LIMIT 1
    ) ts_final ON true
    LEFT JOIN LATERAL (
      SELECT max(day::date) AS range_end_date
      FROM time_slots
      WHERE poll_id = p.id
    ) ts_range ON true
    WHERE p.archived_at IS NULL
      AND (
        (p.status = 'finalized' AND (COALESCE(ts_final.finalized_date, p.created_at::date) + 14) < CURRENT_DATE)
        OR
        (p.status = 'open' AND (COALESCE(ts_range.range_end_date, p.created_at::date) + 7) < CURRENT_DATE)
      )
  LOOP
    v_finalized_date := COALESCE(rec.finalized_date, rec.created_date);
    v_range_end_date := COALESCE(rec.range_end_date, rec.created_date);

    SELECT count(*) INTO v_participant_count FROM participants WHERE poll_id = rec.id;
    SELECT count(*) INTO v_response_count FROM responses WHERE poll_id = rec.id;
    SELECT count(*) INTO v_time_slot_count FROM time_slots WHERE poll_id = rec.id;

    UPDATE polls
    SET archived_at = now(),
        archived_reason = 'expired',
        finalized_for_date = CASE WHEN rec.status = 'finalized' THEN v_finalized_date ELSE finalized_for_date END,
        range_end_date = CASE WHEN rec.status = 'open' THEN v_range_end_date ELSE range_end_date END,
        participant_count = v_participant_count,
        response_count = v_response_count,
        time_slot_count = v_time_slot_count,
        title = '',
        creator_session_id = NULL,
        finalized_slot_id = NULL
    WHERE id = rec.id;

    DELETE FROM responses WHERE poll_id = rec.id;
    DELETE FROM participants WHERE poll_id = rec.id;
    DELETE FROM time_slots WHERE poll_id = rec.id;
    DELETE FROM availability_blocks WHERE poll_id = rec.id;
  END LOOP;
END;
$$;

-- Schedule daily cleanup at 03:00 UTC via pg_cron.
CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'cron'
      AND table_name = 'job'
      AND column_name = 'jobname'
  ) THEN
    IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_expired_polls') THEN
      PERFORM cron.schedule('cleanup_expired_polls', '0 3 * * *', 'SELECT cleanup_expired_polls();');
    END IF;
  ELSE
    IF NOT EXISTS (
      SELECT 1 FROM cron.job
      WHERE schedule = '0 3 * * *'
        AND command = 'CALL cleanup_expired_polls();'
    ) THEN
      PERFORM cron.schedule('0 3 * * *', 'SELECT cleanup_expired_polls();');
    END IF;
  END IF;
END;
$$;
