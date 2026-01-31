import { supabaseRequest } from '../supabaseClient';
import type { DayAvailabilityBlock } from '../types';
import { hasTimeSlots } from './slotRepository';

interface AvailabilityRow {
  id: string;
  poll_id: string;
  day: string;
  start_time: string;
  end_time: string;
}

function toAvailabilityBlock(row: AvailabilityRow): DayAvailabilityBlock {
  const [startHour, startMinute] = row.start_time.split(':').map(Number);
  const [endHour, endMinute] = row.end_time.split(':').map(Number);

  return {
    id: row.id,
    date: row.day,
    startHour,
    startMinute,
    endHour,
    endMinute,
  };
}

function toTimeLabel(hour: number, minute: number): string {
  return `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;
}

export async function listAvailabilityBlocks(pollId: string): Promise<DayAvailabilityBlock[]> {
  const rows = await supabaseRequest<AvailabilityRow[]>('availability_blocks', {
    params: {
      select: '*',
      poll_id: `eq.${pollId}`,
      order: 'day.asc,start_time.asc',
    },
  });

  return rows.map(toAvailabilityBlock);
}

export async function insertAvailabilityBlocks(
  pollId: string,
  blocks: DayAvailabilityBlock[]
): Promise<void> {
  if (!blocks.length) return;
  if (await hasTimeSlots(pollId)) {
    return;
  }

  await supabaseRequest('availability_blocks', {
    method: 'POST',
    headers: {
      Prefer: 'return=minimal',
    },
    body: blocks.map((block) => ({
      id: block.id,
      poll_id: pollId,
      day: block.date,
      start_time: toTimeLabel(block.startHour, block.startMinute),
      end_time: toTimeLabel(block.endHour, block.endMinute),
    })),
  });
}
