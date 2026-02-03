import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { v4 as uuidv4 } from "uuid";

import {
  countDaysWithAvailability,
  formatDateHeader,
  formatDateShort,
  formatSlotDate,
  formatSlotTime,
  formatTime,
  formatTimeShort,
  generateSlotsFromAvailability,
  getDateKey,
  groupSlotsByDate,
  isValidDate,
  parseDateKey,
} from "./availability";
import {
  getOrCreateSessionId,
  getStoredDisplayName,
  setStoredDisplayName,
} from "./identity";
import {
  insertAvailabilityBlocks,
  listAvailabilityBlocks,
} from "./repositories/availabilityRepository";
import {
  createPoll,
  deletePoll,
  finalizePoll,
  getPoll,
  listPolls,
} from "./repositories/pollRepository";
import {
  getParticipant,
  updateDisplayNameForSession,
  upsertParticipant,
} from "./repositories/participantRepository";
import {
  listResponses,
  listResponsesForPolls,
  upsertResponse,
} from "./repositories/responseRepository";
import {
  insertTimeSlots,
  hasTimeSlots,
  listTimeSlots,
  listTimeSlotsForPolls,
} from "./repositories/slotRepository";
import type {
  Availability,
  DayAvailabilityBlock,
  Poll,
  PollRecord,
  PreviewTimeSlot,
  Response,
  TimeSlot,
} from "./types";

export type {
  Availability,
  DayAvailabilityBlock,
  Poll,
  PollRecord,
  PreviewTimeSlot,
  Response,
  TimeSlot,
};

export const queryKeys = {
  database: ["database"] as const,
  user: ["user"] as const,
  polls: ["polls"] as const,
  myPolls: ["polls", "mine"] as const,
  respondedPolls: ["polls", "responded"] as const,
  poll: (id: string) => ["polls", id] as const,
};

function resolveDateRange(
  poll: PollRecord,
  slots: TimeSlot[],
  availability: DayAvailabilityBlock[]
): { start: string; end: string } {
  if (poll.dateRangeStart && poll.dateRangeEnd) {
    return { start: poll.dateRangeStart, end: poll.dateRangeEnd };
  }

  const daysFromSlots = slots.map((slot) => slot.day);
  if (daysFromSlots.length) {
    const sorted = [...new Set(daysFromSlots)].sort();
    return { start: sorted[0], end: sorted[sorted.length - 1] };
  }

  const daysFromAvailability = availability.map((block) => block.date);
  if (daysFromAvailability.length) {
    const sorted = [...new Set(daysFromAvailability)].sort();
    return { start: sorted[0], end: sorted[sorted.length - 1] };
  }

  const fallback = poll.createdAt.split("T")[0];
  return { start: fallback, end: fallback };
}

function buildPollView(
  poll: PollRecord,
  slots: TimeSlot[],
  responses: Response[],
  availability: DayAvailabilityBlock[]
): Poll {
  const { start, end } = resolveDateRange(poll, slots, availability);

  return {
    ...poll,
    creatorId: poll.creatorId ?? "",
    dateRangeStart: start,
    dateRangeEnd: end,
    timeSlots: slots,
    responses,
  };
}

export function useInitDatabase() {
  return useQuery({
    queryKey: queryKeys.database,
    queryFn: async () => true,
    staleTime: Infinity,
  });
}

export function useCurrentUser() {
  return useQuery({
    queryKey: queryKeys.user,
    queryFn: async () => {
      const sessionId = await getOrCreateSessionId();
      const name = await getStoredDisplayName();
      return { id: sessionId, name };
    },
  });
}

export function useSetUserName() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (name: string) => {
      await setStoredDisplayName(name);
      const sessionId = await getOrCreateSessionId();
      await updateDisplayNameForSession(sessionId, name);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.user });
    },
  });
}

export function usePolls() {
  return useQuery({
    queryKey: queryKeys.polls,
    queryFn: async () => {
      const polls = await listPolls();
      const pollIds = polls.map((poll) => poll.id);

      const [slots, responses, availability] = await Promise.all([
        listTimeSlotsForPolls(pollIds),
        listResponsesForPolls(pollIds),
        Promise.all(pollIds.map((pollId) => listAvailabilityBlocks(pollId))),
      ]);

      const availabilityByPoll = new Map<string, DayAvailabilityBlock[]>();
      pollIds.forEach((pollId, index) => {
        availabilityByPoll.set(pollId, availability[index] ?? []);
      });

      const slotsByPoll = new Map<string, TimeSlot[]>();
      for (const slot of slots) {
        const existing = slotsByPoll.get(slot.pollId) ?? [];
        existing.push(slot);
        slotsByPoll.set(slot.pollId, existing);
      }

      const responsesByPoll = new Map<string, Response[]>();
      for (const response of responses) {
        const existing = responsesByPoll.get(response.pollId) ?? [];
        existing.push(response);
        responsesByPoll.set(response.pollId, existing);
      }

      return polls.map((poll) =>
        buildPollView(
          poll,
          slotsByPoll.get(poll.id) ?? [],
          responsesByPoll.get(poll.id) ?? [],
          availabilityByPoll.get(poll.id) ?? []
        )
      );
    },
  });
}

export function useMyPolls() {
  const { data: user } = useCurrentUser();

  return useQuery({
    queryKey: [...queryKeys.myPolls, user?.id ?? ""],
    queryFn: async () => {
      if (!user?.id) return [];
      const polls = await listPolls();
      const myPolls = polls.filter((poll) => poll.creatorId === user.id);
      const pollIds = myPolls.map((poll) => poll.id);

      const [slots, responses, availability] = await Promise.all([
        listTimeSlotsForPolls(pollIds),
        listResponsesForPolls(pollIds),
        Promise.all(pollIds.map((pollId) => listAvailabilityBlocks(pollId))),
      ]);

      const availabilityByPoll = new Map<string, DayAvailabilityBlock[]>();
      pollIds.forEach((pollId, index) => {
        availabilityByPoll.set(pollId, availability[index] ?? []);
      });

      const slotsByPoll = new Map<string, TimeSlot[]>();
      for (const slot of slots) {
        const existing = slotsByPoll.get(slot.pollId) ?? [];
        existing.push(slot);
        slotsByPoll.set(slot.pollId, existing);
      }

      const responsesByPoll = new Map<string, Response[]>();
      for (const response of responses) {
        const existing = responsesByPoll.get(response.pollId) ?? [];
        existing.push(response);
        responsesByPoll.set(response.pollId, existing);
      }

      return myPolls.map((poll) =>
        buildPollView(
          poll,
          slotsByPoll.get(poll.id) ?? [],
          responsesByPoll.get(poll.id) ?? [],
          availabilityByPoll.get(poll.id) ?? []
        )
      );
    },
    enabled: !!user?.id,
  });
}

export function useRespondedPolls() {
  const { data: user } = useCurrentUser();

  return useQuery({
    queryKey: [...queryKeys.respondedPolls, user?.id ?? ""],
    queryFn: async () => {
      if (!user?.id) return [];
      const polls = await listPolls();
      const pollIds = polls.map((poll) => poll.id);

      const [responses, slots, availability] = await Promise.all([
        listResponsesForPolls(pollIds),
        listTimeSlotsForPolls(pollIds),
        Promise.all(pollIds.map((pollId) => listAvailabilityBlocks(pollId))),
      ]);

      const availabilityByPoll = new Map<string, DayAvailabilityBlock[]>();
      pollIds.forEach((pollId, index) => {
        availabilityByPoll.set(pollId, availability[index] ?? []);
      });

      const responsesByPoll = new Map<string, Response[]>();
      for (const response of responses) {
        const existing = responsesByPoll.get(response.pollId) ?? [];
        existing.push(response);
        responsesByPoll.set(response.pollId, existing);
      }

      const slotsByPoll = new Map<string, TimeSlot[]>();
      for (const slot of slots) {
        const existing = slotsByPoll.get(slot.pollId) ?? [];
        existing.push(slot);
        slotsByPoll.set(slot.pollId, existing);
      }

      const responded = polls.filter((poll) =>
        (responsesByPoll.get(poll.id) ?? []).some(
          (response) => response.sessionId === user.id
        )
      );

      return responded.map((poll) =>
        buildPollView(
          poll,
          slotsByPoll.get(poll.id) ?? [],
          responsesByPoll.get(poll.id) ?? [],
          availabilityByPoll.get(poll.id) ?? []
        )
      );
    },
    enabled: !!user?.id,
  });
}

export function usePoll(pollId: string) {
  return useQuery({
    queryKey: queryKeys.poll(pollId),
    queryFn: async () => {
      if (!pollId) return null;

      const poll = await getPoll(pollId);
      if (!poll) return null;

      const [slots, responses, availability] = await Promise.all([
        listTimeSlots(pollId),
        listResponses(pollId),
        listAvailabilityBlocks(pollId),
      ]);

      return buildPollView(poll, slots, responses, availability);
    },
    enabled: !!pollId,
  });
}

export function useCreatePoll() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (pollData: {
      title: string;
      durationMinutes: number;
      dateRangeStart: string;
      dateRangeEnd: string;
      dayAvailability: DayAvailabilityBlock[];
      timeSlots: PreviewTimeSlot[];
    }): Promise<string> => {
      // Validation
      const title = (pollData.title || "").trim() || "Find a time to meet";

      if (!pollData.durationMinutes || pollData.durationMinutes <= 0) {
        throw new Error("Duration must be greater than 0");
      }

      if (!pollData.timeSlots || pollData.timeSlots.length === 0) {
        throw new Error("At least one time slot is required");
      }

      // Validate each slot has valid times
      for (const slot of pollData.timeSlots) {
        if (!slot.day || !slot.startTime || !slot.endTime) {
          throw new Error("Each time slot must have day, startTime, and endTime");
        }
        if (slot.startTime >= slot.endTime) {
          throw new Error("Start time must be before end time for each slot");
        }
      }

      // Validate date range
      if (!pollData.dateRangeStart || !pollData.dateRangeEnd) {
        throw new Error("Date range is required");
      }
      if (pollData.dateRangeStart > pollData.dateRangeEnd) {
        throw new Error("Start date must be before or equal to end date");
      }

      const sessionId = await getOrCreateSessionId();
      const pollId = uuidv4();
      const createdAt = new Date().toISOString();

      const pollRecord: PollRecord = {
        id: pollId,
        title,
        durationMinutes: pollData.durationMinutes,
        status: "open",
        createdAt,
        finalizedSlotId: null,
        finalizedAt: null,
        creatorId: sessionId,
        dateRangeStart: pollData.dateRangeStart,
        dateRangeEnd: pollData.dateRangeEnd,
      };

      await createPoll(pollRecord);

      // Slots are immutable once created; never overwrite existing slots/availability.
      const slotsExist = await hasTimeSlots(pollId);
      if (!slotsExist) {
        await insertAvailabilityBlocks(pollId, pollData.dayAvailability);

        const slots: TimeSlot[] = pollData.timeSlots.map((slot) => ({
          ...slot,
          pollId,
        }));
        await insertTimeSlots(pollId, slots);
      }

      const displayName = await getStoredDisplayName();
      await upsertParticipant({
        pollId,
        sessionId,
        displayName: displayName || undefined,
      });

      return pollId;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.polls });
      queryClient.invalidateQueries({ queryKey: queryKeys.myPolls });
    },
    onError: (error) => {
      console.error("Failed to create poll:", error);
    },
  });
}

export function useAddResponse() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      pollId,
      slotId,
      availability,
      participantName,
    }: {
      pollId: string;
      slotId: string;
      availability: Availability;
      participantName?: string;
    }) => {
      // Validate inputs
      if (!pollId || !slotId || !availability) {
        throw new Error("Missing required fields: pollId, slotId, or availability");
      }

      // Check if poll exists and is not finalized
      const poll = await getPoll(pollId);
      if (!poll) {
        throw new Error("Poll not found");
      }
      if (poll.status === "finalized") {
        throw new Error("Cannot respond to a finalized poll");
      }

      const sessionId = await getOrCreateSessionId();
      const storedName = await getStoredDisplayName();
      const displayName = participantName || storedName || "Anonymous";

      // Ensure participant exists before adding response
      const existingParticipant = await getParticipant(pollId, sessionId);
      if (!existingParticipant) {
        await upsertParticipant({
          pollId,
          sessionId,
          displayName,
        });
      }

      // Save the response
      await upsertResponse(pollId, slotId, sessionId, availability);

      return { pollId, slotId, sessionId, availability };
    },
    onSuccess: (_, { pollId }) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.poll(pollId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.polls });
      queryClient.invalidateQueries({ queryKey: queryKeys.respondedPolls });
    },
    onError: (error) => {
      console.error("Failed to save response:", error);
    },
  });
}

export function useFinalizePoll() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      pollId,
      slotId,
    }: {
      pollId: string;
      slotId: string;
    }) => {
      // Validate inputs
      if (!pollId || !slotId) {
        throw new Error("Missing required fields: pollId or slotId");
      }

      // Check if poll exists and is not already finalized
      const poll = await getPoll(pollId);
      if (!poll) {
        throw new Error("Poll not found");
      }
      if (poll.status === "finalized") {
        throw new Error("Poll is already finalized");
      }

      // Validate slotId belongs to this poll
      const slots = await listTimeSlots(pollId);
      const slotExists = slots.some((s) => s.id === slotId);
      if (!slotExists) {
        throw new Error("Invalid slot for this poll");
      }

      await finalizePoll(pollId, slotId);
    },
    onSuccess: (_, { pollId }) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.poll(pollId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.polls });
    },
    onError: (error) => {
      console.error("Failed to finalize poll:", error);
    },
  });
}

export function useDeletePoll() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (pollId: string) => {
      if (!pollId) {
        throw new Error("Poll ID is required");
      }
      await deletePoll(pollId);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.polls });
      queryClient.invalidateQueries({ queryKey: queryKeys.myPolls });
    },
    onError: (error) => {
      console.error("Failed to delete poll:", error);
    },
  });
}

export {
  countDaysWithAvailability,
  formatDateHeader,
  formatDateShort,
  formatSlotDate,
  formatSlotTime,
  formatTime,
  formatTimeShort,
  generateSlotsFromAvailability,
  getDateKey,
  groupSlotsByDate,
  isValidDate,
  parseDateKey,
};

export function getSlotStats(
  responses: Response[],
  slotId: string
): { yes: number; maybe: number; no: number; total: number } {
  const slotResponses = responses.filter((r) => r.slotId === slotId);
  return {
    yes: slotResponses.filter((r) => r.availability === "yes").length,
    maybe: slotResponses.filter((r) => r.availability === "maybe").length,
    no: slotResponses.filter((r) => r.availability === "no").length,
    total: slotResponses.length,
  };
}

export function rankSlots(
  timeSlots: TimeSlot[],
  responses: Response[]
): TimeSlot[] {
  return [...timeSlots].sort((a, b) => {
    const statsA = getSlotStats(responses, a.id);
    const statsB = getSlotStats(responses, b.id);

    if (statsB.yes !== statsA.yes) return statsB.yes - statsA.yes;
    if (statsA.no !== statsB.no) return statsA.no - statsB.no;
    return statsB.maybe - statsA.maybe;
  });
}

export function getParticipantForPoll(pollId: string, sessionId: string) {
  return getParticipant(pollId, sessionId);
}
