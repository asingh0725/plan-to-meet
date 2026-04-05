// Database row types (snake_case from Supabase)
export interface PollRow {
  id: string
  title: string
  duration_minutes: number
  status: 'open' | 'finalized'
  created_at: string
  creator_session_id: string | null
  finalized_slot_id: string | null
  is_premium?: boolean | null
  details?: string | null
  closes_at?: string | null
}

export interface TimeSlotRow {
  id: string
  poll_id: string
  day: string
  start_time: string
  end_time: string
}

export interface ResponseRow {
  id: string
  poll_id: string
  slot_id: string
  session_id: string
  availability: Availability
}

export interface ParticipantRow {
  poll_id: string
  session_id: string
  display_name: string | null
}

// Frontend types (camelCase)
export type Availability = 'available' | 'maybe' | 'unavailable'

export interface Poll {
  id: string
  title: string
  durationMinutes: number
  status: 'open' | 'finalized'
  createdAt: string
  creatorSessionId: string | null
  finalizedSlotId: string | null
  isPremium: boolean
  details: string | null
  closesAt: string | null
  timeSlots: TimeSlot[]
  responses: Response[]
  participants: Participant[]
}

export interface TimeSlot {
  id: string
  pollId: string
  day: string
  startTime: string
  endTime: string
}

export interface Response {
  id: string
  pollId: string
  slotId: string
  sessionId: string
  availability: Availability
}

export interface Participant {
  pollId: string
  sessionId: string
  displayName: string | null
}

// Utility function to transform snake_case to camelCase
export function transformPoll(row: PollRow): Omit<Poll, 'timeSlots' | 'responses' | 'participants'> {
  return {
    id: row.id,
    title: row.title,
    durationMinutes: row.duration_minutes,
    status: row.status,
    createdAt: row.created_at,
    creatorSessionId: row.creator_session_id,
    finalizedSlotId: row.finalized_slot_id,
    isPremium: row.is_premium ?? false,
    details: row.details ?? null,
    closesAt: row.closes_at ?? null,
  }
}

export function transformTimeSlot(row: TimeSlotRow): TimeSlot {
  return {
    id: row.id,
    pollId: row.poll_id,
    day: row.day,
    startTime: row.start_time,
    endTime: row.end_time,
  }
}

export function transformResponse(row: ResponseRow): Response {
  return {
    id: row.id,
    pollId: row.poll_id,
    slotId: row.slot_id,
    sessionId: row.session_id,
    availability: row.availability,
  }
}

export function transformParticipant(row: ParticipantRow): Participant {
  return {
    pollId: row.poll_id,
    sessionId: row.session_id,
    displayName: row.display_name,
  }
}

// Reaction types
export interface ReactionRow {
  id: string
  poll_id: string
  session_id: string
  emoji: string
  comment: string | null
  created_at: string
}

export interface Reaction {
  id: string
  pollId: string
  sessionId: string
  emoji: string
  comment: string | null
  createdAt: string
}

export function transformReaction(row: ReactionRow): Reaction {
  return {
    id: row.id,
    pollId: row.poll_id,
    sessionId: row.session_id,
    emoji: row.emoji,
    comment: row.comment,
    createdAt: row.created_at,
  }
}

// Slot statistics
export interface SlotStats {
  available: number
  maybe: number
  unavailable: number
  total: number
  score: number
}

export function getSlotStats(responses: Response[], slotId: string): SlotStats {
  const slotResponses = responses.filter((r) => r.slotId === slotId)
  const available = slotResponses.filter((r) => r.availability === 'available').length
  const maybe = slotResponses.filter((r) => r.availability === 'maybe').length
  const unavailable = slotResponses.filter((r) => r.availability === 'unavailable').length

  return {
    available,
    maybe,
    unavailable,
    total: slotResponses.length,
    score: available * 2 + maybe - unavailable, // Scoring: available counts most
  }
}
