import { supabaseRequest } from '../supabase'
import { Availability, ResponseRow, Response, transformResponse } from '../types'

export async function submitResponse(
  pollId: string,
  slotId: string,
  sessionId: string,
  availability: Availability
): Promise<void> {
  // Upsert using the actual unique constraint on (slot_id, session_id)
  await supabaseRequest('responses?on_conflict=slot_id,session_id', {
    method: 'POST',
    body: {
      poll_id: pollId,
      slot_id: slotId,
      session_id: sessionId,
      availability,
    },
    headers: {
      Prefer: 'return=minimal,resolution=merge-duplicates',
    },
  })
}

export async function fetchResponses(pollId: string): Promise<Response[]> {
  const rows = await supabaseRequest<ResponseRow[]>('responses', {
    params: {
      select: '*',
      poll_id: `eq.${pollId}`,
    },
  })

  return (rows || []).map(transformResponse)
}

export async function fetchUserResponses(
  pollId: string,
  sessionId: string
): Promise<Response[]> {
  const rows = await supabaseRequest<ResponseRow[]>('responses', {
    params: {
      select: '*',
      poll_id: `eq.${pollId}`,
      session_id: `eq.${sessionId}`,
    },
  })

  return (rows || []).map(transformResponse)
}
