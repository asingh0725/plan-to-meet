import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
import { format, parseISO } from 'date-fns'
import { TimeSlot } from './types'

// Tailwind class name utility
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// Session ID management
const SESSION_ID_KEY = 'plantomeet_session_id'
const DISPLAY_NAME_KEY = 'plantomeet_display_name'

export function getSessionId(): string {
  if (typeof window === 'undefined') {
    return ''
  }

  let sessionId = localStorage.getItem(SESSION_ID_KEY)

  if (!sessionId) {
    sessionId = crypto.randomUUID()
    localStorage.setItem(SESSION_ID_KEY, sessionId)
  }

  return sessionId
}

export function getDisplayName(): string | null {
  if (typeof window === 'undefined') {
    return null
  }

  return localStorage.getItem(DISPLAY_NAME_KEY)
}

export function setDisplayName(name: string): void {
  if (typeof window === 'undefined') {
    return
  }

  localStorage.setItem(DISPLAY_NAME_KEY, name)
}

// Date formatting utilities
export function formatSlotDate(slot: TimeSlot): string {
  try {
    const date = parseISO(slot.day)
    return format(date, 'EEEE, MMM d')
  } catch {
    return slot.day
  }
}

export function formatSlotTime(slot: TimeSlot): string {
  try {
    const [startHour, startMin] = slot.startTime.split(':').map(Number)
    const [endHour, endMin] = slot.endTime.split(':').map(Number)

    if (isNaN(startHour) || isNaN(endHour)) {
      return `${slot.startTime} - ${slot.endTime}`
    }

    const formatTime = (hour: number, min: number) => {
      const period = hour >= 12 ? 'PM' : 'AM'
      const h = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour
      return min === 0 ? `${h} ${period}` : `${h}:${String(min).padStart(2, '0')} ${period}`
    }

    return `${formatTime(startHour, startMin)} - ${formatTime(endHour, endMin)}`
  } catch {
    return `${slot.startTime} - ${slot.endTime}`
  }
}

export function formatShortDate(dateStr: string): string {
  try {
    const date = parseISO(dateStr)
    return format(date, 'EEE, MMM d')
  } catch {
    return dateStr
  }
}

export function formatFullDate(dateStr: string): string {
  try {
    const date = parseISO(dateStr)
    return format(date, 'EEEE, MMMM d, yyyy')
  } catch {
    return dateStr
  }
}

export function formatTime(timeStr: string): string {
  try {
    const [hour, min] = timeStr.split(':').map(Number)
    const period = hour >= 12 ? 'PM' : 'AM'
    const h = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour
    return min === 0 ? `${h}:00 ${period}` : `${h}:${String(min).padStart(2, '0')} ${period}`
  } catch {
    return timeStr
  }
}

// Generate .ics calendar file content
export function generateICS(
  title: string,
  startDate: Date,
  endDate: Date,
  description?: string
): string {
  const formatICSDate = (date: Date) => {
    return date.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z'
  }

  const uid = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}@plantomeet.app`

  return `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//PlanToMeet//EN
BEGIN:VEVENT
UID:${uid}
DTSTAMP:${formatICSDate(new Date())}
DTSTART:${formatICSDate(startDate)}
DTEND:${formatICSDate(endDate)}
SUMMARY:${title}
${description ? `DESCRIPTION:${description}` : ''}
END:VEVENT
END:VCALENDAR`
}

// Download helper
export function downloadFile(content: string, filename: string, mimeType: string): void {
  const blob = new Blob([content], { type: mimeType })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
}
