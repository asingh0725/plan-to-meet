import { v4 as uuidv4 } from "uuid";

import type {
  BaseTimeSlot,
  DayAvailabilityBlock,
  PreviewTimeSlot,
} from "./types";

export { type DayAvailabilityBlock };

// Availability is defined per-day with independent blocks (no implicit ranges).

export function getDateKey(date: Date): string {
  return date.toISOString().split("T")[0];
}

export function parseDateKey(dateKey: string): Date {
  if (!dateKey || typeof dateKey !== "string") {
    return new Date(NaN);
  }
  const parts = dateKey.split("-");
  if (parts.length !== 3) {
    return new Date(NaN);
  }
  const [year, month, day] = parts.map(Number);
  if (isNaN(year) || isNaN(month) || isNaN(day)) {
    return new Date(NaN);
  }
  return new Date(year, month - 1, day);
}

export function isValidDate(date: Date): boolean {
  return date instanceof Date && !isNaN(date.getTime());
}

export function formatTime(hour: number, minute: number): string {
  const ampm = hour >= 12 ? "PM" : "AM";
  const h = hour % 12 || 12;
  const m = minute.toString().padStart(2, "0");
  return `${h}:${m} ${ampm}`;
}

export function formatTimeShort(hour: number, minute: number): string {
  const ampm = hour >= 12 ? "PM" : "AM";
  const h = hour % 12 || 12;
  if (minute === 0) return `${h} ${ampm}`;
  return `${h}:${minute.toString().padStart(2, "0")} ${ampm}`;
}

export function getBlockDurationMinutes(block: {
  startHour: number;
  startMinute: number;
  endHour: number;
  endMinute: number;
}): number {
  const startMinutes = block.startHour * 60 + block.startMinute;
  const endMinutes = block.endHour * 60 + block.endMinute;
  return endMinutes - startMinutes;
}

export function isBlockValidForDuration(
  block: {
    startHour: number;
    startMinute: number;
    endHour: number;
    endMinute: number;
  },
  durationMinutes: number
): boolean {
  return getBlockDurationMinutes(block) >= durationMinutes;
}

function toTimeLabel(minutes: number): string {
  const hour = Math.floor(minutes / 60);
  const minute = minutes % 60;
  return `${hour.toString().padStart(2, "0")}:${minute
    .toString()
    .padStart(2, "0")}`;
}

export function generateSlotsFromAvailability(
  availabilityBlocks: DayAvailabilityBlock[],
  durationMinutes: number
): PreviewTimeSlot[] {
  const slots: PreviewTimeSlot[] = [];

  for (const block of availabilityBlocks) {
    if (!isBlockValidForDuration(block, durationMinutes)) continue;

    const blockStartMinutes = block.startHour * 60 + block.startMinute;
    const blockEndMinutes = block.endHour * 60 + block.endMinute;

    for (
      let slotStartMin = blockStartMinutes;
      slotStartMin + durationMinutes <= blockEndMinutes;
      slotStartMin += durationMinutes
    ) {
      const slotEndMin = slotStartMin + durationMinutes;
      slots.push({
        id: uuidv4(),
        day: block.date,
        startTime: toTimeLabel(slotStartMin),
        endTime: toTimeLabel(slotEndMin),
      });
    }
  }

  slots.sort((a, b) => {
    if (a.day !== b.day) return a.day.localeCompare(b.day);
    return a.startTime.localeCompare(b.startTime);
  });

  return slots;
}

export function groupSlotsByDate<T extends BaseTimeSlot>(
  slots: T[]
): Map<string, T[]> {
  const groups = new Map<string, T[]>();

  for (const slot of slots) {
    const existing = groups.get(slot.day) || [];
    existing.push(slot);
    groups.set(slot.day, existing);
  }

  return groups;
}

export function getBlocksForDate(
  dayAvailability: DayAvailabilityBlock[],
  dateKey: string
): DayAvailabilityBlock[] {
  return dayAvailability.filter((b) => b.date === dateKey);
}

export function countDaysWithAvailability(
  dayAvailability: DayAvailabilityBlock[]
): number {
  const uniqueDates = new Set(dayAvailability.map((b) => b.date));
  return uniqueDates.size;
}

function buildDate(day: string, time: string) {
  // time = "HH:mm" or "HH:mm:ss"
  // day = "YYYY-MM-DD"
  if (!day || !time) {
    throw new Error("Missing day or time");
  }
  const iso = `${day}T${time}`;
  const date = new Date(iso);

  if (!isValidDate(date)) {
    throw new Error(`Invalid date constructed from ${iso}`);
  }

  return date;
}

export function getSlotDateRange(slot: BaseTimeSlot) {
  if (!slot.day || !slot.startTime || !slot.endTime) {
    throw new Error("Slot missing day/start/end");
  }

  const start = buildDate(slot.day, slot.startTime);
  const end = buildDate(slot.day, slot.endTime);

  return { start, end };
}

export function formatSlotTime(slot: BaseTimeSlot): string {
  try {
    const { start, end } = getSlotDateRange(slot);

    const timeFormat = new Intl.DateTimeFormat("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    });

    return `${timeFormat.format(start)} – ${timeFormat.format(end)}`;
  } catch {
    console.warn("Invalid slot time", slot);
    return "Invalid time";
  }
}

export function formatSlotDate(slot: BaseTimeSlot): string {
  if (!slot?.day) {
    return "Invalid date";
  }
  const date = parseDateKey(slot.day);
  if (!isValidDate(date)) {
    return "Invalid date";
  }

  return new Intl.DateTimeFormat("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
  }).format(date);
}

export function formatDateHeader(dateKey: string): string {
  const date = parseDateKey(dateKey);
  if (!isValidDate(date)) {
    return "Invalid date";
  }
  return new Intl.DateTimeFormat("en-US", {
    weekday: "long",
    month: "short",
    day: "numeric",
  }).format(date);
}

export function formatDateShort(dateKey: string): string {
  const date = parseDateKey(dateKey);
  if (!isValidDate(date)) {
    return "Invalid date";
  }
  return new Intl.DateTimeFormat("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
  }).format(date);
}
