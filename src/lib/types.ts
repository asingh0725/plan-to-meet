export type Availability = 'yes' | 'maybe' | 'no';

export interface DayAvailabilityBlock {
  id: string;
  date: string; // YYYY-MM-DD
  startHour: number;
  startMinute: number;
  endHour: number;
  endMinute: number;
}

export interface BaseTimeSlot {
  id: string;
  day: string; // YYYY-MM-DD
  startTime: string; // HH:mm
  endTime: string; // HH:mm
}

export interface TimeSlot extends BaseTimeSlot {
  pollId: string;
}

export interface PreviewTimeSlot extends BaseTimeSlot {}

export interface Participant {
  pollId: string;
  sessionId: string;
  displayName?: string | null;
}

export interface Response {
  pollId: string;
  slotId: string;
  sessionId: string;
  availability: Availability;
}

export interface PollRecord {
  id: string;
  title: string;
  durationMinutes: number;
  status: 'open' | 'finalized';
  createdAt: string;
  finalizedSlotId: string | null;
  finalizedAt?: string | null;
  creatorId?: string | null;
  dateRangeStart?: string | null;
  dateRangeEnd?: string | null;
}

export interface Poll extends PollRecord {
  creatorId: string;
  dateRangeStart: string;
  dateRangeEnd: string;
  timeSlots: TimeSlot[];
  responses: Response[];
}
