import { describe, it, expect } from 'vitest'
import { formatSlotTime, formatTime, generateICS } from '@/lib/utils'
import type { TimeSlot } from '@/lib/types'

const makeSlot = (startTime: string, endTime: string): TimeSlot => ({
  id: 'slot-1',
  pollId: 'poll-1',
  day: '2025-06-15',
  startTime,
  endTime,
})

describe('formatSlotTime', () => {
  it('formats a morning slot correctly', () => {
    const result = formatSlotTime(makeSlot('09:00', '10:00'))
    expect(result).toBe('9 AM - 10 AM')
  })

  it('formats a PM slot correctly', () => {
    const result = formatSlotTime(makeSlot('14:00', '15:00'))
    expect(result).toBe('2 PM - 3 PM')
  })

  it('formats noon correctly', () => {
    const result = formatSlotTime(makeSlot('12:00', '13:00'))
    expect(result).toBe('12 PM - 1 PM')
  })

  it('formats midnight hour (00:xx) as 12 AM', () => {
    const result = formatSlotTime(makeSlot('00:00', '01:00'))
    expect(result).toBe('12 AM - 1 AM')
  })

  it('includes minutes when non-zero', () => {
    const result = formatSlotTime(makeSlot('09:30', '10:30'))
    expect(result).toBe('9:30 AM - 10:30 AM')
  })

  it('falls back to raw string on invalid time', () => {
    const result = formatSlotTime(makeSlot('bad', 'time'))
    expect(result).toBe('bad - time')
  })
})

describe('formatTime', () => {
  it('formats 09:00 as "9:00 AM"', () => {
    expect(formatTime('09:00')).toBe('9:00 AM')
  })

  it('formats 23:00 as "11:00 PM"', () => {
    expect(formatTime('23:00')).toBe('11:00 PM')
  })

  it('formats 12:00 as "12:00 PM"', () => {
    expect(formatTime('12:00')).toBe('12:00 PM')
  })

  it('formats 00:00 as "12:00 AM"', () => {
    expect(formatTime('00:00')).toBe('12:00 AM')
  })
})

describe('generateICS', () => {
  const start = new Date('2025-06-15T14:00:00Z')
  const end = new Date('2025-06-15T15:00:00Z')

  it('returns valid ICS structure', () => {
    const ics = generateICS('Team Lunch', start, end)
    expect(ics).toContain('BEGIN:VCALENDAR')
    expect(ics).toContain('END:VCALENDAR')
    expect(ics).toContain('BEGIN:VEVENT')
    expect(ics).toContain('END:VEVENT')
  })

  it('includes the event title as SUMMARY', () => {
    const ics = generateICS('Team Lunch', start, end)
    expect(ics).toContain('SUMMARY:Team Lunch')
  })

  it('includes DTSTART and DTEND', () => {
    const ics = generateICS('Team Lunch', start, end)
    expect(ics).toContain('DTSTART:20250615T140000Z')
    expect(ics).toContain('DTEND:20250615T150000Z')
  })

  it('includes description when provided', () => {
    const ics = generateICS('Team Lunch', start, end, 'Via PlanToMeet')
    expect(ics).toContain('DESCRIPTION:Via PlanToMeet')
  })

  it('excludes DESCRIPTION line when not provided', () => {
    const ics = generateICS('Team Lunch', start, end)
    expect(ics).not.toContain('DESCRIPTION:')
  })
})
