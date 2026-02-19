import { supabaseRequest, SupabaseError } from '../supabase'
import {
  PollRow,
  TimeSlotRow,
  ResponseRow,
  ParticipantRow,
  Poll,
  transformPoll,
  transformTimeSlot,
  transformResponse,
  transformParticipant,
} from '../types'

export async function fetchPoll(pollId: string): Promise<Poll | null> {
  try {
    // Fetch poll
    const polls = await supabaseRequest<PollRow[]>('polls', {
      params: {
        select: '*',
        id: `eq.${pollId}`,
        archived_at: 'is.null',
        limit: '1',
      },
    })

    if (!polls || polls.length === 0) {
      return null
    }

    const pollRow = polls[0]

    // Fetch related data in parallel
    const [timeSlotsRows, responsesRows, participantsRows] = await Promise.all([
      supabaseRequest<TimeSlotRow[]>('time_slots', {
        params: {
          select: '*',
          poll_id: `eq.${pollId}`,
          order: 'day.asc,start_time.asc',
        },
      }),
      supabaseRequest<ResponseRow[]>('responses', {
        params: {
          select: '*',
          poll_id: `eq.${pollId}`,
        },
      }),
      supabaseRequest<ParticipantRow[]>('participants', {
        params: {
          select: '*',
          poll_id: `eq.${pollId}`,
        },
      }),
    ])

    return {
      ...transformPoll(pollRow),
      timeSlots: (timeSlotsRows || []).map(transformTimeSlot),
      responses: (responsesRows || []).map(transformResponse),
      participants: (participantsRows || []).map(transformParticipant),
    }
  } catch (error) {
    // Return null for any fetch errors (invalid UUID, network error, etc.)
    // This allows the UI to show "Poll Not Found" gracefully
    if (error instanceof SupabaseError) {
      console.warn(`Poll fetch failed for ${pollId}:`, error.message)
      return null
    }
    throw error
  }
}

export async function fetchPollBasic(pollId: string): Promise<Omit<Poll, 'timeSlots' | 'responses' | 'participants'> | null> {
  try {
    const polls = await supabaseRequest<PollRow[]>('polls', {
      params: {
        select: '*',
        id: `eq.${pollId}`,
        archived_at: 'is.null',
        limit: '1',
      },
    })

    if (!polls || polls.length === 0) {
      return null
    }

    return transformPoll(polls[0])
  } catch (error) {
    if (error instanceof SupabaseError) {
      console.warn(`Poll basic fetch failed for ${pollId}:`, error.message)
      return null
    }
    throw error
  }
}

export async function finalizePoll(pollId: string, slotId: string): Promise<void> {
  await supabaseRequest(`polls?id=eq.${pollId}`, {
    method: 'PATCH',
    body: {
      status: 'finalized',
      finalized_slot_id: slotId,
    },
    headers: {
      Prefer: 'return=minimal',
    },
  })
}

export interface CreatePollInput {
  title: string
  durationMinutes: number
  creatorSessionId: string
  timeSlots: Array<{ day: string; startTime: string; endTime: string }>
}

export async function clonePoll(
  sourcePollId: string,
  newStartDate: string,
  newEndDate: string,
  creatorSessionId: string
): Promise<string> {
  // Fetch source poll and its time slots
  const [sourcePolls, sourceSlots] = await Promise.all([
    supabaseRequest<PollRow[]>('polls', {
      params: { select: '*', id: `eq.${sourcePollId}`, limit: '1' },
    }),
    supabaseRequest<TimeSlotRow[]>('time_slots', {
      params: { select: '*', poll_id: `eq.${sourcePollId}` },
    }),
  ])

  if (!sourcePolls || sourcePolls.length === 0) {
    throw new Error('Source poll not found')
  }
  const source = sourcePolls[0]

  // Extract unique time windows from original slots (HH:MM-HH:MM)
  const windows = [
    ...new Set((sourceSlots || []).map((s) => `${s.start_time}-${s.end_time}`)),
  ]

  // Generate new date list
  const dates: string[] = []
  const start = new Date(newStartDate)
  const end = new Date(newEndDate)
  for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    dates.push(d.toISOString().slice(0, 10))
  }

  const newPollId = crypto.randomUUID()
  const now = new Date().toISOString()

  await supabaseRequest('polls', {
    method: 'POST',
    body: {
      id: newPollId,
      title: source.title,
      duration_minutes: source.duration_minutes,
      status: 'open',
      created_at: now,
      creator_session_id: creatorSessionId,
      parent_poll_id: sourcePollId,
    },
    headers: { Prefer: 'return=minimal' },
  })

  const slotBodies = dates.flatMap((day) =>
    windows.map((w) => {
      const [start_time, end_time] = w.split('-')
      return { id: crypto.randomUUID(), poll_id: newPollId, day, start_time, end_time }
    })
  )

  if (slotBodies.length > 0) {
    await supabaseRequest('time_slots', {
      method: 'POST',
      body: slotBodies,
      headers: { Prefer: 'return=minimal' },
    })
  }

  return newPollId
}

export async function createPoll(input: CreatePollInput): Promise<string> {
  const pollId = crypto.randomUUID()
  const now = new Date().toISOString()

  await supabaseRequest('polls', {
    method: 'POST',
    body: {
      id: pollId,
      title: input.title,
      duration_minutes: input.durationMinutes,
      status: 'open',
      created_at: now,
      creator_session_id: input.creatorSessionId,
    },
    headers: { Prefer: 'return=minimal' },
  })

  const slotBodies = input.timeSlots.map((slot) => ({
    id: crypto.randomUUID(),
    poll_id: pollId,
    day: slot.day,
    start_time: slot.startTime,
    end_time: slot.endTime,
  }))

  await supabaseRequest('time_slots', {
    method: 'POST',
    body: slotBodies,
    headers: { Prefer: 'return=minimal' },
  })

  return pollId
}
