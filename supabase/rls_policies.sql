-- RLS policies for TimeTogether (apply in Supabase SQL editor).
-- These policies assume a custom JWT claim "session_id" is available to match anonymous sessions.

-- Enable RLS
ALTER TABLE polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE time_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE availability_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;

-- Polls: readable by anyone
CREATE POLICY "polls_select_all" ON polls
  FOR SELECT
  USING (true);

-- Polls: only creator can finalize
CREATE POLICY "polls_finalize_creator" ON polls
  FOR UPDATE
  USING (creator_session_id = (current_setting('request.jwt.claims', true)::jsonb ->> 'session_id'))
  WITH CHECK (creator_session_id = (current_setting('request.jwt.claims', true)::jsonb ->> 'session_id'));

-- Slots: readable by anyone, immutable after creation/finalization
CREATE POLICY "time_slots_select_all" ON time_slots
  FOR SELECT
  USING (true);

CREATE POLICY "time_slots_insert_open" ON time_slots
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM polls
      WHERE polls.id = time_slots.poll_id
      AND polls.status = 'open'
    )
  );

CREATE POLICY "time_slots_no_update" ON time_slots
  FOR UPDATE
  USING (false);

CREATE POLICY "time_slots_no_delete" ON time_slots
  FOR DELETE
  USING (false);

-- Availability blocks: readable by anyone, immutable after slots exist or poll finalized
CREATE POLICY "availability_select_all" ON availability_blocks
  FOR SELECT
  USING (true);

CREATE POLICY "availability_insert_open" ON availability_blocks
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM polls
      WHERE polls.id = availability_blocks.poll_id
      AND polls.status = 'open'
    )
    AND NOT EXISTS (
      SELECT 1 FROM time_slots
      WHERE time_slots.poll_id = availability_blocks.poll_id
    )
  );

CREATE POLICY "availability_no_update" ON availability_blocks
  FOR UPDATE
  USING (false);

CREATE POLICY "availability_no_delete" ON availability_blocks
  FOR DELETE
  USING (false);

-- Responses: readable by anyone, insert once per poll/session
CREATE POLICY "responses_select_all" ON responses
  FOR SELECT
  USING (true);

CREATE POLICY "responses_insert_once" ON responses
  FOR INSERT
  WITH CHECK (
    NOT EXISTS (
      SELECT 1 FROM responses r
      WHERE r.poll_id = responses.poll_id
      AND r.session_id = responses.session_id
      AND r.slot_id = responses.slot_id
    )
  );

-- Participants: readable by anyone, upsert per poll/session
CREATE POLICY "participants_select_all" ON participants
  FOR SELECT
  USING (true);

CREATE POLICY "participants_insert" ON participants
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "participants_update_self" ON participants
  FOR UPDATE
  USING (session_id = (current_setting('request.jwt.claims', true)::jsonb ->> 'session_id'))
  WITH CHECK (session_id = (current_setting('request.jwt.claims', true)::jsonb ->> 'session_id'));
