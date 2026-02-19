-- ============================================================
-- PlanToMeet — Push Notification DB Triggers
--
-- Uses pg_net to call the send-push-notification Edge Function
-- directly from PostgreSQL, eliminating the need for manual
-- webhook configuration in the Supabase dashboard.
--
-- Prerequisites:
--   1. Enable the pg_net extension:
--      Project Settings → Database → Extensions → pg_net → Enable
--   2. Deploy the Edge Function:
--      supabase functions deploy send-push-notification
--   3. Set the two database config variables below in the SQL editor:
--      ALTER DATABASE postgres SET app.supabase_url = 'https://<ref>.supabase.co';
--      ALTER DATABASE postgres SET app.service_role_key = '<your-service-role-key>';
--      (get both from: Project Settings → API)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_net;

-- ── Trigger 1: New response inserted → notify poll creator ──────────────────

CREATE OR REPLACE FUNCTION _notify_push_on_response()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  _url  text;
  _key  text;
BEGIN
  BEGIN
    _url := current_setting('app.supabase_url');
    _key := current_setting('app.service_role_key');
  EXCEPTION WHEN OTHERS THEN
    RETURN NEW; -- config not set yet, skip silently
  END;

  PERFORM net.http_post(
    url     := _url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'Authorization', 'Bearer ' || _key
               ),
    body    := jsonb_build_object(
                 'table',  'responses',
                 'record', row_to_json(NEW)
               )::text
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS response_inserted_push ON responses;
CREATE TRIGGER response_inserted_push
  AFTER INSERT ON responses
  FOR EACH ROW
  EXECUTE FUNCTION _notify_push_on_response();

-- ── Trigger 2: Poll finalized → notify all participants ─────────────────────

CREATE OR REPLACE FUNCTION _notify_push_on_finalize()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  _url  text;
  _key  text;
BEGIN
  -- Only fire when status transitions to 'finalized'
  IF NEW.status <> 'finalized' OR OLD.status = 'finalized' THEN
    RETURN NEW;
  END IF;

  BEGIN
    _url := current_setting('app.supabase_url');
    _key := current_setting('app.service_role_key');
  EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
  END;

  PERFORM net.http_post(
    url     := _url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'Authorization', 'Bearer ' || _key
               ),
    body    := jsonb_build_object(
                 'table',      'polls',
                 'record',     row_to_json(NEW),
                 'old_record', row_to_json(OLD)
               )::text
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS poll_finalized_push ON polls;
CREATE TRIGGER poll_finalized_push
  AFTER UPDATE ON polls
  FOR EACH ROW
  EXECUTE FUNCTION _notify_push_on_finalize();
