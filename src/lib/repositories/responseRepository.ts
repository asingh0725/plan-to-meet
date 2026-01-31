import { supabaseRequest } from '../supabaseClient';
import type { Availability, Response } from '../types';

// Database uses 'available'/'unavailable'/'maybe', UI uses 'yes'/'no'/'maybe'
type DbAvailability = 'available' | 'unavailable' | 'maybe';

function toDbAvailability(availability: Availability): DbAvailability {
  switch (availability) {
    case 'yes':
      return 'available';
    case 'no':
      return 'unavailable';
    case 'maybe':
      return 'maybe';
  }
}

function fromDbAvailability(dbValue: DbAvailability): Availability {
  switch (dbValue) {
    case 'available':
      return 'yes';
    case 'unavailable':
      return 'no';
    case 'maybe':
      return 'maybe';
  }
}

interface ResponseRow {
  poll_id: string;
  slot_id: string;
  session_id: string;
  availability: DbAvailability;
}

function toResponse(row: ResponseRow): Response {
  return {
    pollId: row.poll_id,
    slotId: row.slot_id,
    sessionId: row.session_id,
    availability: fromDbAvailability(row.availability),
  };
}

export async function listResponses(pollId: string): Promise<Response[]> {
  const rows = await supabaseRequest<ResponseRow[]>('responses', {
    params: {
      select: '*',
      poll_id: `eq.${pollId}`,
    },
  });

  return rows.map(toResponse);
}

export async function listResponsesForPolls(pollIds: string[]): Promise<Response[]> {
  if (!pollIds.length) return [];

  const rows = await supabaseRequest<ResponseRow[]>('responses', {
    params: {
      select: '*',
      poll_id: `in.(${pollIds.join(',')})`,
    },
  });

  return rows.map(toResponse);
}

export async function upsertResponse(
  pollId: string,
  slotId: string,
  sessionId: string,
  availability: Availability
): Promise<void> {
  const dbAvailability = toDbAvailability(availability);

  // Check if response already exists
  const existing = await supabaseRequest<ResponseRow[]>('responses', {
    params: {
      select: 'poll_id',
      poll_id: `eq.${pollId}`,
      slot_id: `eq.${slotId}`,
      session_id: `eq.${sessionId}`,
      limit: '1',
    },
  });

  if (existing.length > 0) {
    // Update existing response
    await supabaseRequest('responses', {
      method: 'PATCH',
      params: {
        poll_id: `eq.${pollId}`,
        slot_id: `eq.${slotId}`,
        session_id: `eq.${sessionId}`,
      },
      headers: {
        Prefer: 'return=minimal',
      },
      body: {
        availability: dbAvailability,
      },
    });
  } else {
    // Insert new response
    await supabaseRequest('responses', {
      method: 'POST',
      headers: {
        Prefer: 'return=minimal',
      },
      body: {
        poll_id: pollId,
        slot_id: slotId,
        session_id: sessionId,
        availability: dbAvailability,
      },
    });
  }
}
