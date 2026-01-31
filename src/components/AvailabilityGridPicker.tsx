import React, { useState, useCallback, useMemo, useRef } from 'react';
import {
  View,
  Text,
  ScrollView,
  Pressable,
  Dimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ChevronLeft, Check, CalendarDays } from 'lucide-react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import * as ExpoCalendar from 'expo-calendar';
import Animated, { FadeInDown, FadeIn } from 'react-native-reanimated';
import { format, addDays, differenceInDays } from 'date-fns';

import { cn } from '@/lib/cn';
import {
  type DayAvailabilityBlock,
  getDateKey,
  formatTimeShort,
} from '@/lib/availability';
import { v4 as uuidv4 } from 'uuid';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const TIME_LABEL_WIDTH = 50;
const CELL_HEIGHT = 44;
const MIN_COLUMN_WIDTH = 70;

interface CalendarEvent {
  startDate: string;
  endDate: string;
}

interface AvailabilityGridPickerProps {
  dateRangeStart: Date;
  dateRangeEnd: Date;
  durationMinutes: number;
  initialAvailability: DayAvailabilityBlock[];
  calendarEvents?: CalendarEvent[];
  useCalendar?: boolean;
  readOnly?: boolean;
  onSave: (availability: DayAvailabilityBlock[]) => void;
  onCancel: () => void;
}

// Generate time slots for the grid based on duration
function generateTimeRows(durationMinutes: number): { hour: number; minute: number }[] {
  const rows: { hour: number; minute: number }[] = [];
  const slotsPerHour = 60 / durationMinutes;

  // Generate from 6 AM to 11 PM
  for (let hour = 6; hour < 23; hour++) {
    for (let i = 0; i < slotsPerHour; i++) {
      const minute = i * durationMinutes;
      rows.push({ hour, minute });
    }
  }

  return rows;
}

// Generate date columns
function generateDateColumns(start: Date, end: Date): string[] {
  const dates: string[] = [];
  const days = differenceInDays(end, start) + 1;

  for (let i = 0; i < days; i++) {
    dates.push(getDateKey(addDays(start, i)));
  }

  return dates;
}

// Check if a cell has a calendar conflict
function isCellBusy(
  events: CalendarEvent[],
  dateKey: string,
  hour: number,
  minute: number,
  durationMinutes: number
): boolean {
  const cellDate = new Date(dateKey + 'T00:00:00');
  cellDate.setHours(hour, minute, 0, 0);
  const cellStart = cellDate.getTime();
  const cellEnd = cellStart + durationMinutes * 60 * 1000;

  return events.some((event) => {
    const eventStart = new Date(event.startDate).getTime();
    const eventEnd = new Date(event.endDate).getTime();
    // Check for overlap
    return cellStart < eventEnd && cellEnd > eventStart;
  });
}

// Merge adjacent cells into blocks
function mergeCellsIntoBlocks(
  selectedCells: Set<string>,
  durationMinutes: number
): DayAvailabilityBlock[] {
  const blocks: DayAvailabilityBlock[] = [];

  // Group cells by date
  const cellsByDate = new Map<string, { hour: number; minute: number }[]>();

  selectedCells.forEach((cell) => {
    const [dateKey, hourStr, minuteStr] = cell.split('|');
    const existing = cellsByDate.get(dateKey) || [];
    existing.push({ hour: parseInt(hourStr), minute: parseInt(minuteStr) });
    cellsByDate.set(dateKey, existing);
  });

  // For each date, merge adjacent cells into blocks
  cellsByDate.forEach((cells, dateKey) => {
    // Sort cells by time
    cells.sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));

    let blockStart: { hour: number; minute: number } | null = null;
    let blockEnd: { hour: number; minute: number } | null = null;

    for (let i = 0; i < cells.length; i++) {
      const cell = cells[i];
      const cellEndMinutes = cell.hour * 60 + cell.minute + durationMinutes;
      const cellEndHour = Math.floor(cellEndMinutes / 60);
      const cellEndMinute = cellEndMinutes % 60;

      if (!blockStart) {
        blockStart = cell;
        blockEnd = { hour: cellEndHour, minute: cellEndMinute };
      } else {
        // Check if this cell is adjacent to the current block
        const currentEndMinutes = blockEnd!.hour * 60 + blockEnd!.minute;
        const cellStartMinutes = cell.hour * 60 + cell.minute;

        if (cellStartMinutes === currentEndMinutes) {
          // Adjacent - extend block
          blockEnd = { hour: cellEndHour, minute: cellEndMinute };
        } else {
          // Not adjacent - save current block and start new one
          blocks.push({
            id: uuidv4(),
            date: dateKey,
            startHour: blockStart.hour,
            startMinute: blockStart.minute,
            endHour: blockEnd!.hour,
            endMinute: blockEnd!.minute,
          });
          blockStart = cell;
          blockEnd = { hour: cellEndHour, minute: cellEndMinute };
        }
      }
    }

    // Save last block
    if (blockStart && blockEnd) {
      blocks.push({
        id: uuidv4(),
        date: dateKey,
        startHour: blockStart.hour,
        startMinute: blockStart.minute,
        endHour: blockEnd.hour,
        endMinute: blockEnd.minute,
      });
    }
  });

  return blocks;
}

// Convert blocks to selected cells
function blocksToSelectedCells(
  blocks: DayAvailabilityBlock[],
  durationMinutes: number
): Set<string> {
  const cells = new Set<string>();

  for (const block of blocks) {
    const startMinutes = block.startHour * 60 + block.startMinute;
    const endMinutes = block.endHour * 60 + block.endMinute;

    for (let min = startMinutes; min < endMinutes; min += durationMinutes) {
      const hour = Math.floor(min / 60);
      const minute = min % 60;
      cells.add(`${block.date}|${hour}|${minute}`);
    }
  }

  return cells;
}

export default function AvailabilityGridPicker({
  dateRangeStart,
  dateRangeEnd,
  durationMinutes,
  initialAvailability,
  calendarEvents = [],
  useCalendar = false,
  readOnly = false,
  onSave,
  onCancel,
}: AvailabilityGridPickerProps) {
  const timeRows = useMemo(() => generateTimeRows(durationMinutes), [durationMinutes]);
  const dateColumns = useMemo(
    () => generateDateColumns(dateRangeStart, dateRangeEnd),
    [dateRangeStart, dateRangeEnd]
  );

  const [selectedCells, setSelectedCells] = useState<Set<string>>(() =>
    blocksToSelectedCells(initialAvailability, durationMinutes)
  );

  const lastToggledCell = useRef<string | null>(null);
  const headerScrollRef = useRef<ScrollView | null>(null);
  const gridScrollRef = useRef<ScrollView | null>(null);
  const activeHorizontalScroll = useRef<'header' | 'grid' | null>(null);

  // Calculate column width
  const columnWidth = Math.max(
    MIN_COLUMN_WIDTH,
    (SCREEN_WIDTH - TIME_LABEL_WIDTH - 32) / Math.min(dateColumns.length, 5)
  );

  // Check if a cell has a conflict
  const cellHasConflict = useCallback(
    (dateKey: string, hour: number, minute: number): boolean => {
      if (!useCalendar || calendarEvents.length === 0) return false;
      return isCellBusy(calendarEvents, dateKey, hour, minute, durationMinutes);
    },
    [useCalendar, calendarEvents, durationMinutes]
  );

  // Count conflicts in selected cells
  const conflictCount = useMemo(() => {
    if (!useCalendar || calendarEvents.length === 0) return 0;
    let count = 0;
    selectedCells.forEach((cell) => {
      const [dateKey, hourStr, minuteStr] = cell.split('|');
      if (isCellBusy(calendarEvents, dateKey, parseInt(hourStr), parseInt(minuteStr), durationMinutes)) {
        count++;
      }
    });
    return count;
  }, [selectedCells, useCalendar, calendarEvents, durationMinutes]);

  const toggleCell = useCallback((dateKey: string, hour: number, minute: number) => {
    if (readOnly) return;
    const cellKey = `${dateKey}|${hour}|${minute}`;

    if (lastToggledCell.current === cellKey) return;
    lastToggledCell.current = cellKey;

    setSelectedCells((prev) => {
      const newSet = new Set(prev);
      if (newSet.has(cellKey)) {
        newSet.delete(cellKey);
      } else {
        newSet.add(cellKey);
      }
      return newSet;
    });

    Haptics.selectionAsync();
  }, [readOnly]);

  const handleCellPress = useCallback((dateKey: string, hour: number, minute: number) => {
    toggleCell(dateKey, hour, minute);
  }, [toggleCell]);

  const handleSave = useCallback(() => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    const blocks = mergeCellsIntoBlocks(selectedCells, durationMinutes);
    onSave(blocks);
  }, [selectedCells, durationMinutes, onSave]);

  const handleCancel = useCallback(() => {
    Haptics.selectionAsync();
    onCancel();
  }, [onCancel]);

  const selectedCount = selectedCells.size;

  const syncHorizontalScroll = useCallback((x: number, source: 'header' | 'grid') => {
    // Keep header + grid aligned without triggering scroll feedback loops.
    const target = source === 'header' ? gridScrollRef.current : headerScrollRef.current;
    target?.scrollTo({ x, animated: false });
  }, []);

  return (
    <View className="flex-1 bg-zinc-950">
      <LinearGradient
        colors={['#18181b', '#09090b']}
        style={{ position: 'absolute', left: 0, right: 0, top: 0, bottom: 0 }}
      />

      <SafeAreaView className="flex-1">
        {/* Header */}
        <Animated.View
          entering={FadeInDown.springify()}
          className="flex-row items-center justify-between px-5 py-4 border-b border-zinc-800"
        >
          <Pressable
            onPress={handleCancel}
            className="w-10 h-10 items-center justify-center rounded-full bg-zinc-800/50"
          >
            <ChevronLeft size={24} color="#a1a1aa" />
          </Pressable>

          <Text className="text-lg font-semibold text-white">Set Availability</Text>

          <Pressable
            onPress={handleSave}
            className="w-10 h-10 items-center justify-center rounded-full bg-blue-600"
          >
            <Check size={20} color="white" />
          </Pressable>
        </Animated.View>

        {/* Helper Text */}
        <Animated.View
          entering={FadeIn.delay(100)}
          className="px-5 py-3 border-b border-zinc-800/50"
        >
          <Text className="text-zinc-400 text-sm text-center">
            Tap cells to mark when you're available. Each day is independent.
          </Text>
          {readOnly && (
            <Text className="text-zinc-500 text-xs text-center mt-1">
              Availability locked after poll creation
            </Text>
          )}
          {useCalendar && (
            <View className="flex-row items-center justify-center gap-4 mt-2">
              <View className="flex-row items-center gap-1.5">
                <View className="w-3 h-3 rounded bg-zinc-700" />
                <Text className="text-zinc-500 text-xs">Busy</Text>
              </View>
              <View className="flex-row items-center gap-1.5">
                <View className="w-3 h-3 rounded bg-blue-500" />
                <Text className="text-zinc-500 text-xs">Selected</Text>
              </View>
              <View className="flex-row items-center gap-1.5">
                <View className="w-3 h-3 rounded bg-amber-500" />
                <Text className="text-zinc-500 text-xs">Conflict</Text>
              </View>
            </View>
          )}
        </Animated.View>

        {/* Grid Container */}
        <ScrollView
          className="flex-1"
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{ paddingBottom: 100 }}
        >
          {/* Date Headers */}
          <View className="flex-row border-b border-zinc-800">
            <View style={{ width: TIME_LABEL_WIDTH }} />
            <ScrollView
              horizontal
              ref={headerScrollRef}
              showsHorizontalScrollIndicator={false}
              scrollEventThrottle={16}
              onScrollBeginDrag={() => {
                activeHorizontalScroll.current = 'header';
              }}
              onScroll={(event) => {
                if (activeHorizontalScroll.current !== 'header') return;
                syncHorizontalScroll(event.nativeEvent.contentOffset.x, 'header');
              }}
              onScrollEndDrag={() => {
                activeHorizontalScroll.current = null;
              }}
              onMomentumScrollEnd={() => {
                activeHorizontalScroll.current = null;
              }}
              contentContainerStyle={{ flexDirection: 'row' }}
            >
              {dateColumns.map((dateKey) => {
                const date = new Date(dateKey + 'T00:00:00');
                return (
                  <View
                    key={dateKey}
                    style={{ width: columnWidth }}
                    className="items-center py-3 border-r border-zinc-800/50"
                  >
                    <Text className="text-zinc-500 text-xs uppercase">
                      {format(date, 'EEE')}
                    </Text>
                    <Text className="text-white font-semibold mt-0.5">
                      {format(date, 'd')}
                    </Text>
                  </View>
                );
              })}
            </ScrollView>
          </View>

          {/* Time Grid */}
          <View className="flex-row">
            {/* Time Labels */}
            <View style={{ width: TIME_LABEL_WIDTH }}>
              {timeRows.map((row) => (
                <View
                  key={`${row.hour}-${row.minute}`}
                  style={{ height: CELL_HEIGHT }}
                  className="justify-center pr-2"
                >
                  {row.minute === 0 && (
                    <Text className="text-zinc-500 text-xs text-right">
                      {formatTimeShort(row.hour, 0)}
                    </Text>
                  )}
                </View>
              ))}
            </View>

            {/* Grid Cells */}
            <ScrollView
              horizontal
              ref={gridScrollRef}
              showsHorizontalScrollIndicator={false}
              scrollEventThrottle={16}
              onScrollBeginDrag={() => {
                activeHorizontalScroll.current = 'grid';
              }}
              onScroll={(event) => {
                if (activeHorizontalScroll.current !== 'grid') return;
                syncHorizontalScroll(event.nativeEvent.contentOffset.x, 'grid');
              }}
              onScrollEndDrag={() => {
                activeHorizontalScroll.current = null;
              }}
              onMomentumScrollEnd={() => {
                activeHorizontalScroll.current = null;
              }}
              contentContainerStyle={{ flexDirection: 'row' }}
            >
              {dateColumns.map((dateKey) => (
                <View key={dateKey} style={{ width: columnWidth }}>
                  {timeRows.map((row) => {
                    const cellKey = `${dateKey}|${row.hour}|${row.minute}`;
                    const isSelected = selectedCells.has(cellKey);
                    const isBusy = cellHasConflict(dateKey, row.hour, row.minute);
                    const isConflict = isSelected && isBusy;
                    const isHourStart = row.minute === 0;

                    return (
                      <Pressable
                        key={cellKey}
                        onPress={() => handleCellPress(dateKey, row.hour, row.minute)}
                        style={{ height: CELL_HEIGHT }}
                        className={cn(
                          'border-r border-b',
                          isHourStart ? 'border-t-zinc-700' : 'border-t-transparent',
                          'border-zinc-800/30'
                        )}
                      >
                        {/* Background for busy (not selected) */}
                        {isBusy && !isSelected && (
                          <View className="absolute inset-0 bg-zinc-800/60" />
                        )}

                        {/* Selected state */}
                        {isSelected && (
                          <View
                            className={cn(
                              'flex-1 m-0.5 rounded',
                              isConflict ? 'bg-amber-500/70' : 'bg-blue-500/60'
                            )}
                          />
                        )}

                        {/* Busy indicator stripes (not selected) */}
                        {isBusy && !isSelected && (
                          <View className="absolute inset-0 items-center justify-center">
                            <View className="w-full h-0.5 bg-zinc-600/40 rotate-45" />
                          </View>
                        )}
                      </Pressable>
                    );
                  })}
                </View>
              ))}
            </ScrollView>
          </View>
        </ScrollView>

        {/* Footer Summary */}
        <Animated.View
          entering={FadeIn.delay(200)}
          className="absolute bottom-0 left-0 right-0"
        >
          <LinearGradient
            colors={['transparent', '#09090b']}
            style={{ height: 100 }}
          />
          <View className="bg-zinc-950 px-5 pb-10 pt-2">
            <View className="flex-row items-center justify-between mb-3">
              <View>
                <Text className="text-zinc-400 text-sm">
                  {selectedCount === 0
                    ? 'No time slots selected'
                    : `${selectedCount} time ${selectedCount === 1 ? 'slot' : 'slots'} selected`}
                </Text>
                {conflictCount > 0 && (
                  <Text className="text-amber-500 text-xs mt-0.5">
                    {conflictCount} {conflictCount === 1 ? 'conflicts' : 'conflicts'} with calendar
                  </Text>
                )}
              </View>
              {selectedCount > 0 && (
                <Pressable
                  onPress={() => {
                    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                    setSelectedCells(new Set());
                  }}
                >
                  <Text className="text-zinc-500 text-sm">Clear all</Text>
                </Pressable>
              )}
            </View>

            <Pressable
              onPress={handleSave}
              className={cn(
                'py-4 rounded-2xl items-center',
                selectedCount > 0 ? 'bg-blue-600' : 'bg-zinc-800'
              )}
            >
              <Text
                className={cn(
                  'font-semibold text-lg',
                  selectedCount > 0 ? 'text-white' : 'text-zinc-500'
                )}
              >
                {selectedCount > 0 ? 'Save Availability' : 'Select Time Slots'}
              </Text>
            </Pressable>
          </View>
        </Animated.View>
      </SafeAreaView>
    </View>
  );
}
