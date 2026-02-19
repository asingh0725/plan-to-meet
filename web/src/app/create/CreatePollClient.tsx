'use client'

import { useState, useMemo, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { addDays, format, startOfDay, eachDayOfInterval, parseISO } from 'date-fns'
import { createPoll, fetchPollBasic } from '@/lib/api/polls'
import { getSessionId } from '@/lib/utils'

// MARK: - Types

interface SlotInput {
  day: string
  startTime: string
  endTime: string
}

const DURATION_OPTIONS = [
  { label: '30 min', value: 30 },
  { label: '45 min', value: 45 },
  { label: '1 hour', value: 60 },
  { label: '90 min', value: 90 },
  { label: '2 hours', value: 120 },
]

const TIME_OPTIONS = Array.from({ length: 28 }, (_, i) => {
  const totalMinutes = 7 * 60 + i * 30 // Start at 7:00 AM, 30-min steps
  const h = Math.floor(totalMinutes / 60)
  const m = totalMinutes % 60
  const hh = String(h).padStart(2, '0')
  const mm = String(m).padStart(2, '0')
  const period = h >= 12 ? 'PM' : 'AM'
  const displayH = h === 0 ? 12 : h > 12 ? h - 12 : h
  return {
    value: `${hh}:${mm}`,
    label: `${displayH}:${mm === '0' ? '00' : mm} ${period}`,
  }
}) // 7:00 AM – 8:30 PM in 30-min steps

// MARK: - Slot Generation

function generateTimeSlots(
  selectedDays: string[],
  startTime: string,
  endTime: string,
  durationMinutes: number
): SlotInput[] {
  const slots: SlotInput[] = []
  const [startH, startM] = startTime.split(':').map(Number)
  const [endH, endM] = endTime.split(':').map(Number)
  const startMinutes = startH * 60 + startM
  const endMinutes = endH * 60 + endM

  for (const day of selectedDays) {
    let current = startMinutes
    while (current + durationMinutes <= endMinutes) {
      const slotEndMinutes = current + durationMinutes
      const fmt = (m: number) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`
      slots.push({ day, startTime: fmt(current), endTime: fmt(slotEndMinutes) })
      current += durationMinutes
    }
  }
  return slots
}

// MARK: - Create Poll Client

export function CreatePollClient() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [title, setTitle] = useState('')
  const [durationMinutes, setDurationMinutes] = useState(60)
  const [startDate, setStartDate] = useState(() => format(startOfDay(new Date()), 'yyyy-MM-dd'))
  const [endDate, setEndDate] = useState(() => format(addDays(startOfDay(new Date()), 6), 'yyyy-MM-dd'))
  const [dayStartTime, setDayStartTime] = useState('09:00')
  const [dayEndTime, setDayEndTime] = useState('18:00')
  const [isCreating, setIsCreating] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Pre-populate from a cloned poll (?from=pollId)
  useEffect(() => {
    const fromId = searchParams.get('from')
    if (!fromId) return
    fetchPollBasic(fromId).then((poll) => {
      if (!poll) return
      setTitle(poll.title)
      setDurationMinutes(poll.durationMinutes)
    })
  }, [searchParams])

  const selectedDays = useMemo(() => {
    try {
      return eachDayOfInterval({
        start: parseISO(startDate),
        end: parseISO(endDate),
      }).map((d) => format(d, 'yyyy-MM-dd'))
    } catch {
      return []
    }
  }, [startDate, endDate])

  const previewSlots = useMemo(
    () => generateTimeSlots(selectedDays, dayStartTime, dayEndTime, durationMinutes),
    [selectedDays, dayStartTime, dayEndTime, durationMinutes]
  )

  const isFormValid =
    title.trim().length >= 2 && selectedDays.length > 0 && previewSlots.length > 0

  const handleCreate = async () => {
    if (!isFormValid || isCreating) return
    setIsCreating(true)
    setError(null)
    try {
      const sessionId = getSessionId()
      const pollId = await createPoll({
        title: title.trim(),
        durationMinutes,
        creatorSessionId: sessionId,
        timeSlots: previewSlots,
      })
      router.push(`/poll/${pollId}`)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create poll. Please try again.')
      setIsCreating(false)
    }
  }

  return (
    <div className="min-h-screen bg-background px-4 py-8">
      <div className="mx-auto max-w-lg">
        {/* Header */}
        <div className="mb-8">
          <a href="/" className="text-sm text-text-secondary hover:text-text-primary transition-colors mb-6 inline-block">
            ← Back to home
          </a>
          <h1 className="text-3xl font-bold text-text-primary">Create a Poll</h1>
          <p className="text-text-secondary mt-2">Set up your scheduling poll and share the link with your group.</p>
        </div>

        <div className="space-y-6">
          {/* Title */}
          <div className="space-y-2">
            <label className="text-sm font-medium text-text-secondary" htmlFor="poll-title">
              Event Title
            </label>
            <input
              id="poll-title"
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g. Team lunch, Weekend trip planning..."
              maxLength={100}
              className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-text-primary placeholder-text-tertiary outline-none focus:border-accent-blue/50 focus:ring-2 focus:ring-accent-blue/20 transition-all"
            />
          </div>

          {/* Duration */}
          <div className="space-y-2">
            <label className="text-sm font-medium text-text-secondary">Meeting Duration</label>
            <div className="flex flex-wrap gap-2">
              {DURATION_OPTIONS.map((opt) => (
                <button
                  key={opt.value}
                  onClick={() => setDurationMinutes(opt.value)}
                  className={`rounded-full px-4 py-2 text-sm font-medium transition-all ${
                    durationMinutes === opt.value
                      ? 'bg-accent-blue text-white'
                      : 'border border-white/10 bg-white/5 text-text-secondary hover:border-white/20 hover:text-text-primary'
                  }`}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          </div>

          {/* Date Range */}
          <div className="space-y-2">
            <label className="text-sm font-medium text-text-secondary">Date Range</label>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <span className="text-xs text-text-tertiary">From</span>
                <input
                  type="date"
                  value={startDate}
                  min={format(new Date(), 'yyyy-MM-dd')}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2.5 text-sm text-text-primary outline-none focus:border-accent-blue/50 transition-all [color-scheme:dark]"
                />
              </div>
              <div className="space-y-1">
                <span className="text-xs text-text-tertiary">To</span>
                <input
                  type="date"
                  value={endDate}
                  min={startDate}
                  onChange={(e) => setEndDate(e.target.value)}
                  className="w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2.5 text-sm text-text-primary outline-none focus:border-accent-blue/50 transition-all [color-scheme:dark]"
                />
              </div>
            </div>
            <p className="text-xs text-text-tertiary">{selectedDays.length} day{selectedDays.length !== 1 ? 's' : ''} selected</p>
          </div>

          {/* Time Range */}
          <div className="space-y-2">
            <label className="text-sm font-medium text-text-secondary">Time Range Each Day</label>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <span className="text-xs text-text-tertiary">Start</span>
                <select
                  value={dayStartTime}
                  onChange={(e) => setDayStartTime(e.target.value)}
                  className="w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2.5 text-sm text-text-primary outline-none focus:border-accent-blue/50 transition-all"
                >
                  {TIME_OPTIONS.map((opt) => (
                    <option key={opt.value} value={opt.value} className="bg-background">
                      {opt.label}
                    </option>
                  ))}
                </select>
              </div>
              <div className="space-y-1">
                <span className="text-xs text-text-tertiary">End</span>
                <select
                  value={dayEndTime}
                  onChange={(e) => setDayEndTime(e.target.value)}
                  className="w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2.5 text-sm text-text-primary outline-none focus:border-accent-blue/50 transition-all"
                >
                  {TIME_OPTIONS.map((opt) => (
                    <option key={opt.value} value={opt.value} className="bg-background">
                      {opt.label}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          </div>

          {/* Preview */}
          <div className="rounded-xl border border-white/10 bg-white/5 p-4">
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-text-primary">Time slots to vote on</span>
              <span
                className={`rounded-full px-3 py-1 text-xs font-semibold ${
                  previewSlots.length > 0
                    ? 'bg-accent-blue/15 text-accent-blue'
                    : 'bg-white/5 text-text-tertiary'
                }`}
              >
                {previewSlots.length} slots
              </span>
            </div>
            {previewSlots.length === 0 && (
              <p className="mt-2 text-xs text-text-tertiary">
                Adjust the time range or duration to generate slots.
              </p>
            )}
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-start gap-3 rounded-xl border border-red-500/20 bg-red-500/10 p-4">
              <span className="text-red-400 text-sm">{error}</span>
              <button onClick={() => setError(null)} className="ml-auto text-red-400/60 hover:text-red-400 shrink-0">
                ✕
              </button>
            </div>
          )}

          {/* Create Button */}
          <button
            onClick={handleCreate}
            disabled={!isFormValid || isCreating}
            className={`w-full rounded-xl py-4 text-base font-semibold transition-all ${
              isFormValid && !isCreating
                ? 'bg-accent-blue text-white hover:bg-accent-blue/90 active:scale-[0.99]'
                : 'cursor-not-allowed bg-white/5 text-text-tertiary'
            }`}
          >
            {isCreating ? 'Creating your poll...' : 'Create Poll & Get Link'}
          </button>

          <p className="text-center text-xs text-text-tertiary">
            No account needed. Your group votes without signing up.
          </p>
        </div>
      </div>
    </div>
  )
}
