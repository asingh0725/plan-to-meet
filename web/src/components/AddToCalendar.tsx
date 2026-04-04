'use client'

import { useState } from 'react'
import { Calendar, Download, ExternalLink, Check } from 'lucide-react'
import { cn, generateICS, downloadFile, formatFullDate, formatTime } from '@/lib/utils'
import { Poll, TimeSlot } from '@/lib/types'

interface AddToCalendarProps {
  poll: Poll
  slot: TimeSlot
}

export function AddToCalendar({ poll, slot }: AddToCalendarProps) {
  const [downloaded, setDownloaded] = useState(false)

  const handleDownloadICS = () => {
    // Parse the date and time
    const [year, month, day] = slot.day.split('-').map(Number)
    const [startHour, startMin] = slot.startTime.split(':').map(Number)
    const [endHour, endMin] = slot.endTime.split(':').map(Number)

    const startDate = new Date(year, month - 1, day, startHour, startMin)
    const endDate = new Date(year, month - 1, day, endHour, endMin)

    const icsContent = generateICS(
      poll.title || 'PlanToMeet Event',
      startDate,
      endDate,
      `Scheduled via PlanToMeet`
    )

    const filename = `${poll.title || 'event'}.ics`.replace(/[^a-zA-Z0-9.-]/g, '_')
    downloadFile(icsContent, filename, 'text/calendar')
    setDownloaded(true)

    setTimeout(() => setDownloaded(false), 3000)
  }

  const handleGoogleCalendar = () => {
    const [year, month, day] = slot.day.split('-').map(Number)
    const [startHour, startMin] = slot.startTime.split(':').map(Number)
    const [endHour, endMin] = slot.endTime.split(':').map(Number)

    const formatGoogleDate = (y: number, m: number, d: number, h: number, min: number) => {
      return `${y}${String(m).padStart(2, '0')}${String(d).padStart(2, '0')}T${String(h).padStart(2, '0')}${String(min).padStart(2, '0')}00`
    }

    const startStr = formatGoogleDate(year, month, day, startHour, startMin)
    const endStr = formatGoogleDate(year, month, day, endHour, endMin)

    const url = new URL('https://calendar.google.com/calendar/render')
    url.searchParams.set('action', 'TEMPLATE')
    url.searchParams.set('text', poll.title || 'PlanToMeet Event')
    url.searchParams.set('dates', `${startStr}/${endStr}`)
    url.searchParams.set('details', 'Scheduled via PlanToMeet')

    window.open(url.toString(), '_blank')
  }

  return (
    <div className="bg-accent-green/10 border border-accent-green/30 rounded-2xl p-5">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-xl bg-accent-green/20 flex items-center justify-center">
          <Check className="w-5 h-5 text-accent-green" />
        </div>
        <div>
          <p className="font-semibold text-accent-green">Time Finalized!</p>
          <p className="text-sm text-text-secondary">
            {formatFullDate(slot.day)} at {formatTime(slot.startTime)}
          </p>
        </div>
      </div>

      <p className="text-sm text-text-secondary mb-4">
        Add this event to your calendar so you don&apos;t forget.
      </p>

      <div className="flex flex-col sm:flex-row gap-2">
        <button
          onClick={handleDownloadICS}
          className={cn(
            'flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-xl font-medium transition-all',
            downloaded
              ? 'bg-accent-green text-white'
              : 'bg-accent-green/20 text-accent-green hover:bg-accent-green/30'
          )}
        >
          {downloaded ? (
            <>
              <Check className="w-4 h-4" />
              <span>Downloaded!</span>
            </>
          ) : (
            <>
              <Download className="w-4 h-4" />
              <span>Download .ics</span>
            </>
          )}
        </button>

        <button
          onClick={handleGoogleCalendar}
          className="flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-xl font-medium bg-card border border-border text-white hover:bg-card-hover transition-all"
        >
          <Calendar className="w-4 h-4" />
          <span>Google Calendar</span>
          <ExternalLink className="w-3 h-3 opacity-50" />
        </button>
      </div>
    </div>
  )
}
