import { describe, it, expect } from 'vitest'
import { getSlotStats, type Response } from '@/lib/types'

const makeResponse = (slotId: string, availability: 'available' | 'maybe' | 'unavailable'): Response => ({
  id: crypto.randomUUID(),
  pollId: 'poll-1',
  slotId,
  sessionId: crypto.randomUUID(),
  availability,
})

describe('getSlotStats — slot scoring algorithm', () => {
  it('returns zero counts for a slot with no responses', () => {
    const stats = getSlotStats([], 'slot-1')
    expect(stats.available).toBe(0)
    expect(stats.maybe).toBe(0)
    expect(stats.unavailable).toBe(0)
    expect(stats.total).toBe(0)
    expect(stats.score).toBe(0)
  })

  it('scores available = 2 points each', () => {
    const responses: Response[] = [
      makeResponse('slot-1', 'available'),
      makeResponse('slot-1', 'available'),
    ]
    const stats = getSlotStats(responses, 'slot-1')
    expect(stats.available).toBe(2)
    expect(stats.score).toBe(4) // 2 * 2
  })

  it('scores maybe = 1 point each', () => {
    const responses: Response[] = [makeResponse('slot-1', 'maybe')]
    const stats = getSlotStats(responses, 'slot-1')
    expect(stats.maybe).toBe(1)
    expect(stats.score).toBe(1)
  })

  it('scores unavailable = -1 point each', () => {
    const responses: Response[] = [makeResponse('slot-1', 'unavailable')]
    const stats = getSlotStats(responses, 'slot-1')
    expect(stats.unavailable).toBe(1)
    expect(stats.score).toBe(-1)
  })

  it('computes mixed score correctly: available*2 + maybe - unavailable', () => {
    const responses: Response[] = [
      makeResponse('slot-1', 'available'),  // +2
      makeResponse('slot-1', 'available'),  // +2
      makeResponse('slot-1', 'maybe'),      // +1
      makeResponse('slot-1', 'unavailable'), // -1
    ]
    const stats = getSlotStats(responses, 'slot-1')
    expect(stats.available).toBe(2)
    expect(stats.maybe).toBe(1)
    expect(stats.unavailable).toBe(1)
    expect(stats.total).toBe(4)
    expect(stats.score).toBe(4) // 2*2 + 1 - 1
  })

  it('ignores responses for other slot IDs', () => {
    const responses: Response[] = [
      makeResponse('slot-1', 'available'),
      makeResponse('slot-2', 'available'),
      makeResponse('slot-2', 'available'),
    ]
    const stats = getSlotStats(responses, 'slot-1')
    expect(stats.available).toBe(1)
    expect(stats.total).toBe(1)
  })

  it('all unavailable produces negative score', () => {
    const responses: Response[] = [
      makeResponse('slot-1', 'unavailable'),
      makeResponse('slot-1', 'unavailable'),
      makeResponse('slot-1', 'unavailable'),
    ]
    const stats = getSlotStats(responses, 'slot-1')
    expect(stats.score).toBe(-3)
  })

  it('2 available ties with 4 maybe: both score 4', () => {
    const slot1Responses = [makeResponse('slot-1', 'available'), makeResponse('slot-1', 'available')]
    const slot2Responses = [
      makeResponse('slot-2', 'maybe'),
      makeResponse('slot-2', 'maybe'),
      makeResponse('slot-2', 'maybe'),
      makeResponse('slot-2', 'maybe'),
    ]
    const stats1 = getSlotStats(slot1Responses, 'slot-1')
    const stats2 = getSlotStats(slot2Responses, 'slot-2')
    // 2 available = 2*2 = 4, 4 maybe = 4*1 = 4 — equal score, valid tie
    expect(stats1.score).toBe(stats2.score)
  })
})
