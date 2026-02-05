import React, { useCallback, useMemo, useState, useRef, useEffect, memo } from "react";
import {
  View,
  Text,
  Pressable,
  ScrollView,
  Share,
  Alert,
  Platform,
  ActivityIndicator,
} from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import {
  ChevronLeft,
  Share2,
  Clock,
  Check,
  X,
  HelpCircle,
  Users,
  Trophy,
  Trash2,
} from "lucide-react-native";
import { LinearGradient } from "expo-linear-gradient";
import * as Haptics from "expo-haptics";
import * as Clipboard from "expo-clipboard";
import * as ExpoCalendar from "expo-calendar";
import Animated, { FadeInDown, FadeInUp } from "react-native-reanimated";

import { cn } from "@/lib/cn";
import {
  usePoll,
  useCurrentUser,
  useAddResponse,
  useFinalizePoll,
  useDeletePoll,
  formatSlotTime,
  formatSlotDate,
  getSlotStats,
  type Availability,
  type TimeSlot,
  type Response,
} from "@/lib/use-database";

// -------------------------
// TimeSlotCard Component (Memoized)
// -------------------------
interface TimeSlotCardProps {
  slot: TimeSlot;
  responses: Response[];
  userResponse: Availability | null;
  onRespond: (slotId: string, availability: Availability) => void;
  isFinalized: boolean;
  isBestOption: boolean;
  isSelected: boolean;
}

const TimeSlotCard = memo(function TimeSlotCard({
  slot,
  responses,
  userResponse,
  onRespond,
  isFinalized,
  isBestOption,
  isSelected,
}: TimeSlotCardProps) {
  const stats = getSlotStats(responses, slot.id);

  const handlePress = useCallback(
    (availability: Availability) => {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      onRespond(slot.id, availability);
    },
    [onRespond, slot.id]
  );

  return (
    <View
      className={cn(
        "bg-zinc-900 border rounded-2xl p-4 mb-3",
        isSelected
          ? "border-emerald-500 bg-emerald-950/30"
          : isBestOption && !isFinalized
          ? "border-blue-500/50"
          : "border-zinc-800"
      )}
    >
      {/* Header */}
      <View className="flex-row items-center justify-between mb-3">
        <View>
          <Text className="text-white font-semibold text-base">
            {formatSlotDate(slot)}
          </Text>
          <Text className="text-zinc-400 text-sm mt-0.5">
            {formatSlotTime(slot)}
          </Text>
        </View>

        {isSelected && (
          <View className="bg-emerald-600 px-3 py-1 rounded-full flex-row items-center gap-1">
            <Check size={14} color="white" />
            <Text className="text-white text-xs font-semibold">Selected</Text>
          </View>
        )}

        {isBestOption && !isFinalized && !isSelected && (
          <View className="bg-blue-600/20 px-3 py-1 rounded-full flex-row items-center gap-1">
            <Trophy size={14} color="#60a5fa" />
            <Text className="text-blue-400 text-xs font-medium">Best</Text>
          </View>
        )}
      </View>

      {/* Stats */}
      {stats.total > 0 && (
        <View className="flex-row items-center gap-4 mb-3">
          <View className="flex-row items-center gap-1">
            <View className="w-2 h-2 rounded-full bg-emerald-500" />
            <Text className="text-zinc-400 text-xs">{stats.yes} yes</Text>
          </View>
          <View className="flex-row items-center gap-1">
            <View className="w-2 h-2 rounded-full bg-amber-500" />
            <Text className="text-zinc-400 text-xs">{stats.maybe} maybe</Text>
          </View>
          <View className="flex-row items-center gap-1">
            <View className="w-2 h-2 rounded-full bg-rose-500" />
            <Text className="text-zinc-400 text-xs">{stats.no} no</Text>
          </View>
        </View>
      )}

      {/* Response Buttons */}
      {!isFinalized && (
        <View className="flex-row gap-2">
          <Pressable
            onPress={() => handlePress("yes")}
            className={cn(
              "flex-1 py-3 rounded-xl flex-row items-center justify-center gap-2 border",
              userResponse === "yes"
                ? "bg-emerald-600 border-emerald-500"
                : "bg-zinc-800/50 border-zinc-700"
            )}
          >
            <Check
              size={18}
              color={userResponse === "yes" ? "white" : "#a1a1aa"}
            />
            <Text
              className={cn(
                "font-medium",
                userResponse === "yes" ? "text-white" : "text-zinc-400"
              )}
            >
              Yes
            </Text>
          </Pressable>

          <Pressable
            onPress={() => handlePress("maybe")}
            className={cn(
              "flex-1 py-3 rounded-xl flex-row items-center justify-center gap-2 border",
              userResponse === "maybe"
                ? "bg-amber-600 border-amber-500"
                : "bg-zinc-800/50 border-zinc-700"
            )}
          >
            <HelpCircle
              size={18}
              color={userResponse === "maybe" ? "white" : "#a1a1aa"}
            />
            <Text
              className={cn(
                "font-medium",
                userResponse === "maybe" ? "text-white" : "text-zinc-400"
              )}
            >
              Maybe
            </Text>
          </Pressable>

          <Pressable
            onPress={() => handlePress("no")}
            className={cn(
              "flex-1 py-3 rounded-xl flex-row items-center justify-center gap-2 border",
              userResponse === "no"
                ? "bg-rose-600 border-rose-500"
                : "bg-zinc-800/50 border-zinc-700"
            )}
          >
            <X size={18} color={userResponse === "no" ? "white" : "#a1a1aa"} />
            <Text
              className={cn(
                "font-medium",
                userResponse === "no" ? "text-white" : "text-zinc-400"
              )}
            >
              No
            </Text>
          </Pressable>
        </View>
      )}
    </View>
  );
});

// -------------------------
// Main Component
// -------------------------
export default function PollDetailScreen() {
  const { id } = useLocalSearchParams<{ id?: string }>();
  const router = useRouter();
  const pollId = typeof id === "string" ? id : null;

  // -------------------------
  // LOCAL STATE
  // -------------------------
  // Optimistic responses: slotId -> availability
  const [localResponses, setLocalResponses] = useState<Record<string, Availability>>({});
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const errorTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pendingMutations = useRef<Set<string>>(new Set());

  // Cleanup timeout on unmount
  useEffect(() => {
    return () => {
      if (errorTimeoutRef.current) {
        clearTimeout(errorTimeoutRef.current);
      }
    };
  }, []);

  // -------------------------
  // DATA HOOKS
  // -------------------------
  const pollQuery = usePoll(pollId ?? "");
  const userQuery = useCurrentUser();
  const addResponseMutation = useAddResponse();
  const finalizePollMutation = useFinalizePoll();
  const deletePollMutation = useDeletePoll();

  const poll = pollQuery.data;
  const user = userQuery.data;
  const currentUserId = user?.id ?? "";
  const isCreator = poll?.creatorId === currentUserId;
  const isFinalized = poll?.status === "finalized";

  // -------------------------
  // SYNC LOCAL STATE WITH SERVER
  // -------------------------
  // Initialize local responses from server data when poll loads
  useEffect(() => {
    if (!poll || !currentUserId) return;

    const serverResponses: Record<string, Availability> = {};
    for (const r of poll.responses) {
      if (r.sessionId === currentUserId) {
        serverResponses[r.slotId] = r.availability;
      }
    }

    // Only update if there are no pending mutations
    // This prevents server data from overwriting optimistic updates
    setLocalResponses((prev) => {
      const next: Record<string, Availability> = { ...serverResponses };
      // Keep optimistic values for pending mutations
      for (const slotId of pendingMutations.current) {
        if (prev[slotId] !== undefined) {
          next[slotId] = prev[slotId];
        }
      }
      return next;
    });
  }, [poll, currentUserId]);

  // -------------------------
  // DERIVED DATA
  // -------------------------
  // Sort slots by date/time, not by response count (prevents reordering on vote)
  const sortedSlots = useMemo(() => {
    if (!poll) return [];
    return [...(poll.timeSlots ?? [])].sort((a, b) => {
      const dayCompare = a.day.localeCompare(b.day);
      if (dayCompare !== 0) return dayCompare;
      return a.startTime.localeCompare(b.startTime);
    });
  }, [poll]);

  // Calculate best slot index for badge display
  const bestSlotId = useMemo(() => {
    if (!poll || !poll.responses.length) return null;

    let bestId: string | null = null;
    let bestScore = -Infinity;

    for (const slot of poll.timeSlots) {
      const stats = getSlotStats(poll.responses, slot.id);
      // Score: yes counts most, subtract no, maybe is neutral
      const score = stats.yes * 2 - stats.no;
      if (score > bestScore) {
        bestScore = score;
        bestId = slot.id;
      }
    }
    return bestId;
  }, [poll]);

  const respondentCount = useMemo(() => {
    if (!poll) return 0;
    return new Set(poll.responses.map((r) => r.sessionId)).size;
  }, [poll]);

  // -------------------------
  // CALLBACKS
  // -------------------------
  const showErrorToast = useCallback((message: string) => {
    setErrorMessage(message);
    if (errorTimeoutRef.current) {
      clearTimeout(errorTimeoutRef.current);
    }
    errorTimeoutRef.current = setTimeout(() => {
      setErrorMessage(null);
    }, 3000);
  }, []);

  const handleRespond = useCallback(
    (slotId: string, availability: Availability) => {
      if (!poll) return;

      // Optimistically update local state immediately
      setLocalResponses((prev) => ({
        ...prev,
        [slotId]: availability,
      }));

      // Track pending mutation
      pendingMutations.current.add(slotId);

      addResponseMutation.mutate(
        {
          pollId: poll.id,
          slotId,
          availability,
        },
        {
          onSettled: () => {
            // Remove from pending regardless of success/error
            pendingMutations.current.delete(slotId);
          },
          onError: (error) => {
            console.error("Failed to save response:", error);
            showErrorToast("Failed to save your response. Please try again.");
            // Revert to server state on error
            if (poll) {
              const serverResponse = poll.responses.find(
                (r) => r.sessionId === currentUserId && r.slotId === slotId
              );
              setLocalResponses((prev) => {
                const next = { ...prev };
                if (serverResponse) {
                  next[slotId] = serverResponse.availability;
                } else {
                  delete next[slotId];
                }
                return next;
              });
            }
          },
        }
      );
    },
    [poll, addResponseMutation, showErrorToast, currentUserId]
  );

  const handleShare = useCallback(async () => {
    if (!poll) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);

    const shareMessage = `${poll.title}\n\nHelp us find a time to meet! Respond here:\nplantomeet://poll/${poll.id}`;

    if (Platform.OS === "web") {
      try {
        await Clipboard.setStringAsync(shareMessage);
        Alert.alert("Copied!", "Poll link copied to clipboard");
      } catch (error) {
        console.log("Clipboard error:", error);
      }
      return;
    }

    try {
      await Share.share({ message: shareMessage, title: poll.title });
    } catch (error) {
      try {
        await Clipboard.setStringAsync(shareMessage);
        Alert.alert("Copied!", "Poll link copied to clipboard");
      } catch (clipboardError) {
        console.log("Share and clipboard failed:", error, clipboardError);
      }
    }
  }, [poll]);

  const handleFinalize = useCallback(
    (slotId: string) => {
      if (!isCreator || !poll) return;
      finalizePollMutation.mutate({ pollId: poll.id, slotId });
    },
    [isCreator, poll, finalizePollMutation]
  );

  const handleDelete = useCallback(() => {
    if (!isCreator || !poll) return;

    Alert.alert("Delete Poll", "This action cannot be undone.", [
      { text: "Cancel", style: "cancel" },
      {
        text: "Delete",
        style: "destructive",
        onPress: async () => {
          await deletePollMutation.mutateAsync(poll.id);
          router.back();
        },
      },
    ]);
  }, [isCreator, poll, deletePollMutation, router]);

  const handleCreateCalendarEvent = useCallback(async () => {
    if (!poll?.finalizedSlotId) return;

    const slot = poll.timeSlots.find((s) => s.id === poll.finalizedSlotId);
    if (!slot) return;

    const start = new Date(`${slot.day}T${slot.startTime}`);
    const end = new Date(`${slot.day}T${slot.endTime}`);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      Alert.alert("Invalid time", "Unable to create calendar event.");
      return;
    }

    const { status } = await ExpoCalendar.requestCalendarPermissionsAsync();
    if (status !== "granted") return;

    const calendars = await ExpoCalendar.getCalendarsAsync(
      ExpoCalendar.EntityTypes.EVENT
    );
    const calendar = calendars.find((c) => c.isPrimary) ?? calendars[0];
    if (!calendar) return;

    await ExpoCalendar.createEventAsync(calendar.id, {
      title: poll.title,
      startDate: start,
      endDate: end,
      timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    });

    Alert.alert("Event added to calendar");
  }, [poll]);

  const handleBack = useCallback(() => {
    Haptics.selectionAsync();
    router.back();
  }, [router]);

  // -------------------------
  // EARLY RETURNS
  // -------------------------
  if (!pollId) {
    return (
      <View className="flex-1 bg-zinc-950 items-center justify-center">
        <Text className="text-white">Invalid poll</Text>
      </View>
    );
  }

  if (pollQuery.isLoading) {
    return (
      <View className="flex-1 bg-zinc-950 items-center justify-center">
        <ActivityIndicator size="large" color="#3b82f6" />
      </View>
    );
  }

  if (pollQuery.isError || !poll) {
    return (
      <View className="flex-1 bg-zinc-950 items-center justify-center px-6">
        <Text className="text-white text-lg font-semibold mb-2">
          Poll not found
        </Text>
        <Pressable
          onPress={() => router.replace("/")}
          className="px-5 py-3 rounded-xl bg-blue-600"
        >
          <Text className="text-white font-semibold">Back to Home</Text>
        </Pressable>
      </View>
    );
  }

  // -------------------------
  // RENDER
  // -------------------------
  return (
    <View className="flex-1 bg-zinc-950">
      <SafeAreaView className="flex-1">
        {/* Header */}
        <Animated.View
          entering={FadeInDown.delay(100).springify()}
          className="flex-row items-center justify-between px-5 py-4"
        >
          <Pressable
            onPress={handleBack}
            className="w-10 h-10 items-center justify-center rounded-full bg-zinc-800/50"
          >
            <ChevronLeft size={24} color="#a1a1aa" />
          </Pressable>

          <View className="flex-row gap-2">
            {isCreator && !isFinalized && (
              <Pressable
                onPress={handleDelete}
                className="w-10 h-10 items-center justify-center rounded-full bg-zinc-800/50"
              >
                <Trash2 size={20} color="#f87171" />
              </Pressable>
            )}
            <Pressable
              onPress={handleShare}
              className="w-10 h-10 items-center justify-center rounded-full bg-zinc-800/50"
            >
              <Share2 size={20} color="#a1a1aa" />
            </Pressable>
          </View>
        </Animated.View>

        <ScrollView
          className="flex-1 px-5"
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{
            paddingBottom: isCreator && !isFinalized ? 120 : 40,
          }}
        >
          {/* Poll Info */}
          <Animated.View
            entering={FadeInUp.delay(200).springify()}
            className="mb-6"
          >
            <Text className="text-white text-2xl font-bold mb-2">
              {poll.title}
            </Text>
            <Text className="text-zinc-500 text-xs">
              Availability locked after poll creation
            </Text>

            <View className="flex-row items-center gap-4 mt-2">
              <View className="flex-row items-center gap-1.5">
                <Clock size={16} color="#a1a1aa" />
                <Text className="text-zinc-400 text-sm">
                  {poll.durationMinutes < 60
                    ? `${poll.durationMinutes} min`
                    : `${poll.durationMinutes / 60} hour${
                        poll.durationMinutes > 60 ? "s" : ""
                      }`}
                </Text>
              </View>

              <View className="flex-row items-center gap-1.5">
                <Users size={16} color="#a1a1aa" />
                <Text className="text-zinc-400 text-sm">
                  {respondentCount}{" "}
                  {respondentCount === 1 ? "response" : "responses"}
                </Text>
              </View>
            </View>

            {isFinalized && (
              <View className="mt-4 bg-emerald-950/50 border border-emerald-800 rounded-xl p-4">
                <View className="flex-row items-center gap-2">
                  <Check size={18} color="#34d399" />
                  <Text className="text-emerald-400 font-semibold">
                    Time Finalized
                  </Text>
                </View>
                {poll.finalizedSlotId && (
                  <Text className="text-zinc-400 mt-1">
                    {formatSlotDate(
                      poll.timeSlots.find(
                        (s: TimeSlot) => s.id === poll.finalizedSlotId
                      )!
                    )}{" "}
                    at{" "}
                    {formatSlotTime(
                      poll.timeSlots.find(
                        (s: TimeSlot) => s.id === poll.finalizedSlotId
                      )!
                    )}
                  </Text>
                )}
                {poll.finalizedSlotId && (
                  <Pressable
                    onPress={handleCreateCalendarEvent}
                    className="mt-3 px-3 py-2 rounded-lg bg-emerald-900/60 self-start"
                  >
                    <Text className="text-emerald-300 text-xs font-semibold">
                      Create Calendar Event
                    </Text>
                  </Pressable>
                )}
              </View>
            )}
          </Animated.View>

          {/* Time Slots */}
          <View>
            <View className="flex-row items-center justify-between mb-4">
              <Text className="text-zinc-400 text-sm font-medium">
                Time Slots
              </Text>
              <Text className="text-zinc-600 text-xs">
                {sortedSlots.length} options
              </Text>
            </View>

            {sortedSlots.map((slot) => (
              <TimeSlotCard
                key={slot.id}
                slot={slot}
                responses={poll.responses}
                userResponse={localResponses[slot.id] ?? null}
                onRespond={handleRespond}
                isFinalized={isFinalized ?? false}
                isBestOption={slot.id === bestSlotId}
                isSelected={poll.finalizedSlotId === slot.id}
              />
            ))}
          </View>
        </ScrollView>

        {/* Finalize Button (Creator Only) */}
        {isCreator && !isFinalized && sortedSlots.length > 0 && bestSlotId && (
          <Animated.View
            entering={FadeInUp.delay(400).springify()}
            className="absolute bottom-0 left-0 right-0 p-5 pb-10"
          >
            <LinearGradient
              colors={["transparent", "#09090b"]}
              style={{
                position: "absolute",
                left: 0,
                right: 0,
                bottom: 0,
                height: 140,
              }}
            />
            <Pressable
              onPress={() => handleFinalize(bestSlotId)}
              className="bg-emerald-600 py-4 rounded-2xl items-center active:scale-[0.98]"
            >
              <View className="flex-row items-center gap-2">
                <Check size={20} color="white" />
                <Text className="text-white font-semibold text-lg">
                  Finalize Best Time
                </Text>
              </View>
            </Pressable>
          </Animated.View>
        )}

        {/* Error Toast */}
        {errorMessage && (
          <View className="absolute left-5 right-5 bottom-28">
            <View className="bg-red-600/95 rounded-2xl px-4 py-3 shadow-lg">
              <Text className="text-white text-sm font-semibold text-center">
                {errorMessage}
              </Text>
            </View>
          </View>
        )}
      </SafeAreaView>
    </View>
  );
}
