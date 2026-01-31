import React, { useState, useCallback, useMemo, useEffect, useRef } from 'react';
import {
  View,
  Text,
  TextInput,
  Pressable,
  ScrollView,
  Platform,
  KeyboardAvoidingView,
  Modal,
  Switch,
  Alert,
} from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import {
  Calendar,
  Clock,
  ChevronLeft,
  Check,
  CalendarDays,
  AlertCircle,
  ChevronRight,
  CalendarCheck,
} from 'lucide-react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import * as ExpoCalendar from 'expo-calendar';
import Animated, { FadeInDown, FadeInUp, FadeIn } from 'react-native-reanimated';
import DateTimePicker from '@react-native-community/datetimepicker';
import { format, addDays, differenceInDays, startOfDay, endOfDay } from 'date-fns';

import { cn } from '@/lib/cn';
import {
  useCreatePoll,
  countDaysWithAvailability,
  formatDateHeader,
  formatSlotTime,
  generateSlotsFromAvailability,
  getDateKey,
  groupSlotsByDate,
  type DayAvailabilityBlock,
  type PreviewTimeSlot,
} from '@/lib/use-database';
import { getSlotDateRange } from '@/lib/availability';
import AvailabilityGridPicker from '@/components/AvailabilityGridPicker';

const DURATIONS = [15, 30, 60, 90, 120];
const MAX_PREVIEW_SLOTS_PER_DAY = 3;

// Calendar event type for conflict checking
interface CalendarEvent {
  startDate: string;
  endDate: string;
}

// Check if a slot conflicts with calendar events
function slotHasConflict(
  slot: PreviewTimeSlot,
  events: CalendarEvent[]
): boolean {
  const { start, end } = getSlotDateRange(slot);
  const slotStart = start.getTime();
  const slotEnd = end.getTime();

  return events.some((event) => {
    const eventStart = new Date(event.startDate).getTime();
    const eventEnd = new Date(event.endDate).getTime();
    return slotStart < eventEnd && slotEnd > eventStart;
  });
}

export default function CreatePollScreen() {
  const router = useRouter();
  const createPollMutation = useCreatePoll();

  const [title, setTitle] = useState('');
  const [duration, setDuration] = useState(60);
  const [dateRangeStart, setDateRangeStart] = useState(new Date());
  const [dateRangeEnd, setDateRangeEnd] = useState(addDays(new Date(), 6));
  const [dayAvailability, setDayAvailability] = useState<DayAvailabilityBlock[]>([]);
  const [showGridPicker, setShowGridPicker] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const errorTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Calendar integration state
  const [useCalendar, setUseCalendar] = useState(false);
  const [calendarEvents, setCalendarEvents] = useState<CalendarEvent[]>([]);
  const [calendarPermission, setCalendarPermission] = useState<boolean | null>(null);

  // Date picker state
  const [datePicker, setDatePicker] = useState<{
    visible: boolean;
    field: 'start' | 'end';
  }>({ visible: false, field: 'start' });

  // Calculate number of days (inclusive)
  const dayCount = useMemo(() => {
    return differenceInDays(dateRangeEnd, dateRangeStart) + 1;
  }, [dateRangeStart, dateRangeEnd]);

  // Generate preview slots
  const previewSlots = useMemo(() => {
    return generateSlotsFromAvailability(dayAvailability, duration);
  }, [dayAvailability, duration]);

  // Group slots by date for preview
  const slotsByDate = useMemo(() => {
    return groupSlotsByDate(previewSlots);
  }, [previewSlots]);

  // Count days with availability
  const daysWithAvailability = useMemo(() => {
    return countDaysWithAvailability(dayAvailability);
  }, [dayAvailability]);

  // Count conflicts in preview slots
  const conflictCount = useMemo(() => {
    if (!useCalendar || calendarEvents.length === 0) return 0;
    return previewSlots.filter((slot) => slotHasConflict(slot, calendarEvents)).length;
  }, [previewSlots, useCalendar, calendarEvents]);

  // Fetch calendar events when calendar is enabled or date range changes
  useEffect(() => {
    return () => {
      if (errorTimeoutRef.current) {
        clearTimeout(errorTimeoutRef.current);
      }
    };
  }, []);

  useEffect(() => {
    if (!useCalendar || !calendarPermission) {
      setCalendarEvents([]);
      return;
    }

    const fetchEvents = async () => {
      try {
        const calendars = await ExpoCalendar.getCalendarsAsync(ExpoCalendar.EntityTypes.EVENT);
        const calendarIds = calendars.map((c) => c.id);

        if (calendarIds.length === 0) return;

        const events = await ExpoCalendar.getEventsAsync(
          calendarIds,
          startOfDay(dateRangeStart),
          endOfDay(dateRangeEnd)
        );

        setCalendarEvents(
          events.map((e) => ({
            startDate: typeof e.startDate === 'string' ? e.startDate : e.startDate.toISOString(),
            endDate: typeof e.endDate === 'string' ? e.endDate : e.endDate.toISOString(),
          }))
        );
      } catch (error) {
        console.log('Error fetching calendar events:', error);
        setCalendarEvents([]);
      }
    };

    fetchEvents();
  }, [useCalendar, calendarPermission, dateRangeStart, dateRangeEnd]);

  // Handle calendar toggle
  const handleCalendarToggle = useCallback(async (value: boolean) => {
    if (value) {
      // Request permission
      const { status } = await ExpoCalendar.requestCalendarPermissionsAsync();
      if (status === 'granted') {
        setCalendarPermission(true);
        setUseCalendar(true);
        Haptics.selectionAsync();
      } else {
        setCalendarPermission(false);
        setUseCalendar(false);
        // Show alert about permission
        Alert.alert(
          'Calendar Access',
          'To show your busy times, please enable calendar access in Settings.',
          [{ text: 'OK' }]
        );
      }
    } else {
      setUseCalendar(false);
      setCalendarEvents([]);
      Haptics.selectionAsync();
    }
  }, []);

  // Validation
  const canCreatePoll = previewSlots.length > 0;

  const showErrorToast = useCallback((message: string) => {
    setErrorMessage(message);
    if (errorTimeoutRef.current) {
      clearTimeout(errorTimeoutRef.current);
    }
    errorTimeoutRef.current = setTimeout(() => {
      setErrorMessage(null);
    }, 3000);
  }, []);

  const handleCreatePoll = useCallback(async () => {
    if (!canCreatePoll) return;

    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);

    try {
      const pollId = await createPollMutation.mutateAsync({
        title: title.trim() || 'Find a time to meet',
        durationMinutes: duration,
        dateRangeStart: getDateKey(dateRangeStart),
        dateRangeEnd: getDateKey(dateRangeEnd),
        dayAvailability,
        timeSlots: previewSlots,
      });

      router.replace(`/poll/${pollId}`);
    } catch (error) {
      console.log('Error creating poll:', error);
      showErrorToast('Something went wrong. Please try again.');
    }
  }, [
    title,
    duration,
    dateRangeStart,
    dateRangeEnd,
    dayAvailability,
    previewSlots,
    createPollMutation,
    router,
    canCreatePoll,
    showErrorToast,
  ]);

  const formatDurationLabel = (d: number) => {
    if (d < 60) return `${d}-minute`;
    if (d === 60) return '1-hour';
    return `${d / 60}-hour`;
  };

  const handleDurationSelect = (d: number) => {
    Haptics.selectionAsync();
    setDuration(d);
  };

  // Date picker handlers
  const openDatePicker = (field: 'start' | 'end') => {
    setDatePicker({ visible: true, field });
  };

  const handleDateChange = (event: unknown, selectedDate?: Date) => {
    if (Platform.OS === 'android') {
      setDatePicker((prev) => ({ ...prev, visible: false }));
    }

    if (selectedDate) {
      if (datePicker.field === 'start') {
        if (selectedDate < dateRangeEnd) {
          setDateRangeStart(selectedDate);
          // Clear availability when date range changes
          setDayAvailability([]);
        }
      } else {
        if (selectedDate > dateRangeStart) {
          setDateRangeEnd(selectedDate);
          // Clear availability when date range changes
          setDayAvailability([]);
        }
      }

      if (Platform.OS === 'android') {
        Haptics.selectionAsync();
      }
    }
  };

  const confirmDatePicker = () => {
    Haptics.selectionAsync();
    setDatePicker((prev) => ({ ...prev, visible: false }));
  };

  const handleOpenGridPicker = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setShowGridPicker(true);
  };

  const handleSaveAvailability = (availability: DayAvailabilityBlock[]) => {
    setDayAvailability(availability);
    setShowGridPicker(false);
  };

  const handleCancelGridPicker = () => {
    setShowGridPicker(false);
  };

  // Show grid picker as full screen modal
  if (showGridPicker) {
    return (
      <AvailabilityGridPicker
        dateRangeStart={dateRangeStart}
        dateRangeEnd={dateRangeEnd}
        durationMinutes={duration}
        initialAvailability={dayAvailability}
        calendarEvents={calendarEvents}
        useCalendar={useCalendar}
        onSave={handleSaveAvailability}
        onCancel={handleCancelGridPicker}
      />
    );
  }

  return (
    <View className="flex-1 bg-zinc-950">
      <LinearGradient
        colors={['#18181b', '#09090b']}
        style={{ position: 'absolute', left: 0, right: 0, top: 0, bottom: 0 }}
      />

      <SafeAreaView className="flex-1">
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          className="flex-1"
        >
          {/* Header */}
          <Animated.View
            entering={FadeInDown.delay(100).springify()}
            className="flex-row items-center justify-between px-5 py-4"
          >
            <Pressable
              onPress={() => {
                Haptics.selectionAsync();
                router.back();
              }}
              className="w-10 h-10 items-center justify-center rounded-full bg-zinc-800/50"
            >
              <ChevronLeft size={24} color="#a1a1aa" />
            </Pressable>

            <Text className="text-lg font-semibold text-white">New Poll</Text>

            <View className="w-10" />
          </Animated.View>

          <ScrollView
            className="flex-1 px-5"
            showsVerticalScrollIndicator={false}
            contentContainerStyle={{ paddingBottom: 160 }}
          >
            {/* Event Title */}
            <Animated.View entering={FadeInUp.delay(150).springify()} className="mt-2">
              <Text className="text-zinc-400 text-sm font-medium mb-2">
                Event Title (optional)
              </Text>
              <TextInput
                value={title}
                onChangeText={setTitle}
                placeholder="e.g. Team lunch, Study session..."
                placeholderTextColor="#52525b"
                className="bg-zinc-900 border border-zinc-800 rounded-xl px-4 py-4 text-white text-base"
              />
            </Animated.View>

            {/* Duration */}
            <Animated.View entering={FadeInUp.delay(200).springify()} className="mt-6">
              <View className="flex-row items-center mb-3">
                <Clock size={18} color="#a1a1aa" />
                <Text className="text-zinc-400 text-sm font-medium ml-2">Duration</Text>
              </View>
              <View className="flex-row gap-2">
                {DURATIONS.map((d) => (
                  <Pressable
                    key={d}
                    onPress={() => handleDurationSelect(d)}
                    className={cn(
                      'flex-1 py-3 rounded-xl border items-center justify-center',
                      duration === d
                        ? 'bg-blue-600 border-blue-500'
                        : 'bg-zinc-900 border-zinc-800'
                    )}
                  >
                    <Text
                      className={cn(
                        'font-semibold',
                        duration === d ? 'text-white' : 'text-zinc-400'
                      )}
                    >
                      {d < 60 ? `${d}m` : `${d / 60}h`}
                    </Text>
                  </Pressable>
                ))}
              </View>
              <Text className="text-zinc-500 text-xs mt-2">
                Time options will be generated in {formatDurationLabel(duration)} increments
              </Text>
            </Animated.View>

            {/* Date Range */}
            <Animated.View entering={FadeInUp.delay(250).springify()} className="mt-6">
              <View className="flex-row items-center mb-3">
                <Calendar size={18} color="#a1a1aa" />
                <Text className="text-zinc-400 text-sm font-medium ml-2">Date Range</Text>
              </View>

              <View className="flex-row gap-3">
                <Pressable
                  onPress={() => openDatePicker('start')}
                  className="flex-1 bg-zinc-900 border border-zinc-800 rounded-xl p-4"
                >
                  <Text className="text-zinc-500 text-xs mb-1">From</Text>
                  <Text className="text-white font-medium text-base">
                    {format(dateRangeStart, 'MMM d, yyyy')}
                  </Text>
                </Pressable>

                <Pressable
                  onPress={() => openDatePicker('end')}
                  className="flex-1 bg-zinc-900 border border-zinc-800 rounded-xl p-4"
                >
                  <Text className="text-zinc-500 text-xs mb-1">To</Text>
                  <Text className="text-white font-medium text-base">
                    {format(dateRangeEnd, 'MMM d, yyyy')}
                  </Text>
                </Pressable>
              </View>

              <Text className="text-zinc-500 text-xs mt-2 text-center">
                {dayCount} {dayCount === 1 ? 'day' : 'days'} selected
              </Text>
            </Animated.View>

            {/* Availability Section */}
            <Animated.View entering={FadeInUp.delay(300).springify()} className="mt-6">
              <View className="flex-row items-center mb-3">
                <CalendarDays size={18} color="#a1a1aa" />
                <Text className="text-zinc-400 text-sm font-medium ml-2">
                  Your Availability
                </Text>
              </View>

              {/* Calendar Toggle */}
              <View className="flex-row items-center justify-between p-4 bg-zinc-900 border border-zinc-800 rounded-xl mb-3">
                <View className="flex-1 flex-row items-center">
                  <CalendarCheck size={20} color="#3b82f6" />
                  <View className="ml-3 flex-1">
                    <Text className="text-white font-medium">
                      Use my calendar
                    </Text>
                    <Text className="text-zinc-500 text-xs mt-0.5">
                      Show busy times while selecting
                    </Text>
                  </View>
                </View>
                <Switch
                  value={useCalendar}
                  onValueChange={handleCalendarToggle}
                  trackColor={{ false: '#3f3f46', true: '#3b82f6' }}
                  thumbColor="#ffffff"
                />
              </View>
              {useCalendar && (
                <Text className="text-zinc-500 text-xs mb-3 px-1">
                  Your calendar stays on your device. We only use it to highlight conflicts.
                </Text>
              )}

              <Pressable
                onPress={handleOpenGridPicker}
                className={cn(
                  'flex-row items-center justify-between p-4 rounded-xl border',
                  dayAvailability.length > 0
                    ? 'bg-blue-600/10 border-blue-600/30'
                    : 'bg-zinc-900 border-zinc-800'
                )}
              >
                <View className="flex-1">
                  <Text
                    className={cn(
                      'font-medium',
                      dayAvailability.length > 0 ? 'text-blue-400' : 'text-white'
                    )}
                  >
                    {dayAvailability.length > 0
                      ? `${daysWithAvailability} ${daysWithAvailability === 1 ? 'day' : 'days'} with availability`
                      : 'Set availability on calendar'}
                  </Text>
                  <Text className="text-zinc-500 text-xs mt-0.5">
                    {dayAvailability.length > 0
                      ? 'Tap to edit your availability'
                      : 'Mark when you\'re free on each day'}
                  </Text>
                </View>
                <ChevronRight size={20} color="#a1a1aa" />
              </Pressable>

              <Text className="text-zinc-500 text-xs mt-3">
                Mark your availability for specific days and times. Each day is independent.
              </Text>
            </Animated.View>

            {/* Slot Preview */}
            <Animated.View
              entering={FadeInUp.delay(350).springify()}
              className="mt-6 bg-zinc-900 border border-zinc-700 rounded-2xl p-5"
            >
              <Text className="text-white text-base font-semibold mb-4">
                Time Options Preview
              </Text>

              {previewSlots.length === 0 ? (
                <View className="items-center py-4">
                  <AlertCircle size={24} color="#f59e0b" />
                  <Text className="text-amber-500 text-sm mt-2 text-center">
                    No time slots available yet.{'\n'}
                    Set your availability on the calendar above.
                  </Text>
                </View>
              ) : (
                <>
                  {Array.from(slotsByDate.entries()).map(([dateKey, slots], dateIndex) => (
                    <View key={dateKey} className={cn(dateIndex > 0 && 'mt-4')}>
                      <Text className="text-zinc-400 text-xs uppercase tracking-wide mb-2">
                        {formatDateHeader(dateKey)}
                      </Text>
                      {slots.slice(0, MAX_PREVIEW_SLOTS_PER_DAY).map((slot, slotIndex) => {
                        const hasConflict = useCalendar && slotHasConflict(slot, calendarEvents);
                        return (
                          <View
                            key={slot.id}
                            className={cn(
                              'py-2 flex-row items-center justify-between',
                              slotIndex < Math.min(slots.length, MAX_PREVIEW_SLOTS_PER_DAY) - 1 &&
                                'border-b border-zinc-800'
                            )}
                          >
                            <Text className={cn(
                              'text-sm',
                              hasConflict ? 'text-amber-400' : 'text-zinc-300'
                            )}>
                              {formatSlotTime(slot)}
                            </Text>
                            {hasConflict && (
                              <View className="flex-row items-center">
                                <AlertCircle size={12} color="#f59e0b" />
                                <Text className="text-amber-500 text-xs ml-1">Conflict</Text>
                              </View>
                            )}
                          </View>
                        );
                      })}
                      {slots.length > MAX_PREVIEW_SLOTS_PER_DAY && (
                        <Text className="text-zinc-500 text-xs mt-1">
                          +{slots.length - MAX_PREVIEW_SLOTS_PER_DAY} more
                        </Text>
                      )}
                    </View>
                  ))}

                  <View className="h-px bg-zinc-800 my-4" />

                  <View className="flex-row items-center justify-between">
                    <View>
                      <Text className="text-zinc-400 text-sm">Time options to vote on</Text>
                      {conflictCount > 0 && (
                        <Text className="text-amber-500 text-xs mt-0.5">
                          {conflictCount} {conflictCount === 1 ? 'slot has' : 'slots have'} calendar conflicts
                        </Text>
                      )}
                    </View>
                    <View className="bg-blue-600/20 px-3 py-1.5 rounded-full">
                      <Text className="text-blue-400 text-sm font-semibold">
                        {previewSlots.length} {previewSlots.length === 1 ? 'slot' : 'slots'}
                      </Text>
                    </View>
                  </View>
                </>
              )}
            </Animated.View>
          </ScrollView>

          {/* Create Button */}
          <Animated.View
            entering={FadeInUp.delay(400).springify()}
            className="absolute bottom-0 left-0 right-0 p-5 pb-10"
          >
            <LinearGradient
              colors={['transparent', '#09090b']}
              style={{
                position: 'absolute',
                left: 0,
                right: 0,
                bottom: 0,
                height: 140,
              }}
            />
            <Pressable
              onPress={handleCreatePoll}
              disabled={!canCreatePoll}
              className={cn(
                'py-4 rounded-2xl items-center active:scale-[0.98]',
                canCreatePoll ? 'bg-blue-600' : 'bg-zinc-800'
              )}
            >
              <View className="flex-row items-center gap-2">
                <Check size={20} color={canCreatePoll ? 'white' : '#71717a'} />
                <Text
                  className={cn(
                    'font-semibold text-lg',
                    canCreatePoll ? 'text-white' : 'text-zinc-500'
                  )}
                >
                  Create Poll
                </Text>
              </View>
            </Pressable>
          </Animated.View>
        </KeyboardAvoidingView>
      </SafeAreaView>

      {errorMessage && (
        <View className="absolute left-5 right-5 bottom-28">
          <View className="bg-red-600/95 rounded-2xl px-4 py-3 shadow-lg">
            <Text className="text-white text-sm font-semibold text-center">
              {errorMessage}
            </Text>
          </View>
        </View>
      )}

      {/* Date Picker Modal (iOS) */}
      {Platform.OS === 'ios' && datePicker.visible && (
        <Modal transparent animationType="slide">
          <View className="flex-1 justify-end">
            <Pressable
              className="flex-1"
              onPress={() => setDatePicker((prev) => ({ ...prev, visible: false }))}
            />
            <View className="bg-zinc-900 rounded-t-3xl">
              <View className="flex-row items-center justify-between px-5 py-4 border-b border-zinc-800">
                <Pressable onPress={() => setDatePicker((prev) => ({ ...prev, visible: false }))}>
                  <Text className="text-zinc-400 text-base">Cancel</Text>
                </Pressable>
                <Text className="text-white font-semibold">
                  Select {datePicker.field === 'start' ? 'Start' : 'End'} Date
                </Text>
                <Pressable onPress={confirmDatePicker}>
                  <Text className="text-blue-500 font-semibold text-base">Done</Text>
                </Pressable>
              </View>
              <DateTimePicker
                value={datePicker.field === 'start' ? dateRangeStart : dateRangeEnd}
                mode="date"
                display="spinner"
                onChange={handleDateChange}
                minimumDate={datePicker.field === 'start' ? new Date() : dateRangeStart}
                themeVariant="dark"
                style={{ height: 200 }}
              />
            </View>
          </View>
        </Modal>
      )}

      {/* Date Picker (Android) */}
      {Platform.OS === 'android' && datePicker.visible && (
        <DateTimePicker
          value={datePicker.field === 'start' ? dateRangeStart : dateRangeEnd}
          mode="date"
          display="default"
          onChange={handleDateChange}
          minimumDate={datePicker.field === 'start' ? new Date() : dateRangeStart}
        />
      )}
    </View>
  );
}
