import { describe, it, expect } from 'vitest'
import {
  transformPoll,
  transformTimeSlot,
  transformResponse,
  transformParticipant,
  type PollRow,
  type TimeSlotRow,
  type ResponseRow,
  type ParticipantRow,
} from '@/lib/types'

describe('transformPoll', () => {
  const pollRow: PollRow = {
    id: 'poll-abc',
    title: 'Team Standup',
    duration_minutes: 30,
    status: 'open',
    created_at: '2025-01-01T12:00:00Z',
    creator_session_id: 'session-xyz',
    finalized_slot_id: null,
  }

  it('maps snake_case fields to camelCase', () => {
    const poll = transformPoll(pollRow)
    expect(poll.id).toBe('poll-abc')
    expect(poll.durationMinutes).toBe(30)
    expect(poll.creatorSessionId).toBe('session-xyz')
    expect(poll.finalizedSlotId).toBeNull()
    expect(poll.createdAt).toBe('2025-01-01T12:00:00Z')
  })

  it('preserves status', () => {
    const poll = transformPoll(pollRow)
    expect(poll.status).toBe('open')
  })

  it('handles finalized_slot_id when set', () => {
    const finalized = transformPoll({ ...pollRow, finalized_slot_id: 'slot-123', status: 'finalized' })
    expect(finalized.finalizedSlotId).toBe('slot-123')
    expect(finalized.status).toBe('finalized')
  })
})

describe('transformTimeSlot', () => {
  const slotRow: TimeSlotRow = {
    id: 'slot-1',
    poll_id: 'poll-abc',
    day: '2025-06-15',
    start_time: '09:00',
    end_time: '10:00',
  }

  it('maps poll_id, start_time, end_time to camelCase', () => {
    const slot = transformTimeSlot(slotRow)
    expect(slot.pollId).toBe('poll-abc')
    expect(slot.startTime).toBe('09:00')
    expect(slot.endTime).toBe('10:00')
    expect(slot.day).toBe('2025-06-15')
  })
})

describe('transformResponse', () => {
  const responseRow: ResponseRow = {
    id: 'resp-1',
    poll_id: 'poll-abc',
    slot_id: 'slot-1',
    session_id: 'sess-1',
    availability: 'available',
  }

  it('maps slot_id and session_id to camelCase', () => {
    const response = transformResponse(responseRow)
    expect(response.slotId).toBe('slot-1')
    expect(response.sessionId).toBe('sess-1')
    expect(response.availability).toBe('available')
  })
})

describe('transformParticipant', () => {
  const row: ParticipantRow = {
    poll_id: 'poll-abc',
    session_id: 'sess-1',
    display_name: 'Alice',
  }

  it('maps poll_id and session_id and display_name', () => {
    const p = transformParticipant(row)
    expect(p.pollId).toBe('poll-abc')
    expect(p.sessionId).toBe('sess-1')
    expect(p.displayName).toBe('Alice')
  })

  it('handles null display_name', () => {
    const p = transformParticipant({ ...row, display_name: null })
    expect(p.displayName).toBeNull()
  })
})
