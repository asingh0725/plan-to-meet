import { supabaseRequest } from '../supabaseClient';
import type { PollRecord } from '../types';

interface PollRow {
  id: string;
  title: string;
  duration_minutes: number;
  status: string;
  created_at: string;
  finalized_slot_id: string | null;
  finalized_at?: string | null;
  creator_id?: string | null;
  creator_session_id?: string | null;
  date_range_start?: string | null;
  date_range_end?: string | null;
}

function mapPollRow(row: PollRow): PollRecord {
  return {
    id: row.id,
    title: row.title,
    durationMinutes: row.duration_minutes,
    status: row.status as PollRecord['status'],
    createdAt: row.created_at,
    finalizedSlotId: row.finalized_slot_id ?? null,
    finalizedAt: row.finalized_at ?? null,
    creatorId: row.creator_id ?? row.creator_session_id ?? null,
  };
}

export async function listPolls(): Promise<PollRecord[]> {
  const rows = await supabaseRequest<PollRow[]>('polls', {
    params: {
      select: '*',
      order: 'created_at.desc',
    },
  });

  return rows.map(mapPollRow);
}

export async function getPoll(pollId: string): Promise<PollRecord | null> {
  const rows = await supabaseRequest<PollRow[]>('polls', {
    params: {
      select: '*',
      id: `eq.${pollId}`,
      limit: '1',
    },
  });

  if (!rows.length) return null;
  return mapPollRow(rows[0]);
}

export async function createPoll(poll: PollRecord): Promise<void> {
  await supabaseRequest('polls', {
    method: 'POST',
    headers: {
      Prefer: 'return=minimal',
    },
    body: {
      id: poll.id,
      title: poll.title,
      duration_minutes: poll.durationMinutes,
      status: poll.status,
      created_at: poll.createdAt,
      finalized_slot_id: poll.finalizedSlotId,
      finalized_at: poll.finalizedAt ?? null,
      creator_session_id: poll.creatorId ?? null,
    },
  });
}

export async function finalizePoll(pollId: string, slotId: string): Promise<void> {
  await supabaseRequest('polls', {
    method: 'PATCH',
    params: {
      id: `eq.${pollId}`,
    },
    headers: {
      Prefer: 'return=minimal',
    },
    body: {
      status: 'finalized',
      finalized_slot_id: slotId,
      finalized_at: new Date().toISOString(),
    },
  });
}

export async function deletePoll(pollId: string): Promise<void> {
  await supabaseRequest('polls', {
    method: 'DELETE',
    params: {
      id: `eq.${pollId}`,
    },
    headers: {
      Prefer: 'return=minimal',
    },
  });
}
