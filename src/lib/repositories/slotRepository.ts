import { supabaseRequest } from '../supabaseClient';
import type { TimeSlot } from '../types';

interface TimeSlotRow {
  id: string;
  poll_id: string;
  day: string;
  start_time: string;
  end_time: string;
}

function toTimeSlot(row: TimeSlotRow): TimeSlot {
  return {
    id: row.id,
    pollId: row.poll_id,
    day: row.day,
    startTime: row.start_time,
    endTime: row.end_time,
  };
}

export async function listTimeSlots(pollId: string): Promise<TimeSlot[]> {
  const rows = await supabaseRequest<TimeSlotRow[]>('time_slots', {
    params: {
      select: '*',
      poll_id: `eq.${pollId}`,
      order: 'day.asc,start_time.asc',
    },
  });

  return rows.map(toTimeSlot);
}

export async function hasTimeSlots(pollId: string): Promise<boolean> {
  const rows = await supabaseRequest<Pick<TimeSlotRow, 'id'>[]>('time_slots', {
    params: {
      select: 'id',
      poll_id: `eq.${pollId}`,
      limit: '1',
    },
  });

  return rows.length > 0;
}

export async function listTimeSlotsForPolls(pollIds: string[]): Promise<TimeSlot[]> {
  if (!pollIds.length) return [];

  const rows = await supabaseRequest<TimeSlotRow[]>('time_slots', {
    params: {
      select: '*',
      poll_id: `in.(${pollIds.join(',')})`,
      order: 'day.asc,start_time.asc',
    },
  });

  return rows.map(toTimeSlot);
}

export async function insertTimeSlots(pollId: string, slots: TimeSlot[]): Promise<void> {
  if (!slots.length) return;

  await supabaseRequest('time_slots', {
    method: 'POST',
    headers: {
      Prefer: 'return=minimal',
    },
    body: slots.map((slot) => ({
      id: slot.id,
      poll_id: pollId,
      day: slot.day,
      start_time: slot.startTime,
      end_time: slot.endTime,
    })),
  });
}
