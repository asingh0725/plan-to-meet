import React, { useMemo } from 'react';
import { View, Text, Pressable, ScrollView, ActivityIndicator } from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import {
  Plus,
  Calendar,
  Clock,
  Users,
  ChevronRight,
  Check,
  Settings,
} from 'lucide-react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import Animated, {
  FadeInDown,
  FadeInUp,
  FadeIn,
} from 'react-native-reanimated';
import { cn } from '@/lib/cn';
import {
  usePolls,
  useCurrentUser,
  formatSlotDate,
  formatSlotTime,
  type Poll,
  type TimeSlot,
  type Response,
} from '@/lib/use-database';

type PollWithDetails = Poll & { timeSlots: TimeSlot[]; responses: Response[] };

interface PollCardProps {
  poll: PollWithDetails;
  currentUserId: string;
  onPress: () => void;
  index: number;
}

function PollCard({ poll, currentUserId, onPress, index }: PollCardProps) {
  const isCreator = poll.creatorId === currentUserId;
  const isFinalized = poll.status === 'finalized';

  const respondentCount = useMemo(() => {
    const uniqueParticipants = new Set(poll.responses.map((r) => r.sessionId));
    return uniqueParticipants.size;
  }, [poll.responses]);

  const finalizedSlot = useMemo(() => {
    if (!poll.finalizedSlotId) return null;
    return poll.timeSlots.find((s) => s.id === poll.finalizedSlotId);
  }, [poll.finalizedSlotId, poll.timeSlots]);

  return (
    <Animated.View entering={FadeInUp.delay(100 + index * 50).springify()}>
      <Pressable
        onPress={() => {
          Haptics.selectionAsync();
          onPress();
        }}
        className={cn(
          'bg-zinc-900 border rounded-2xl p-4 mb-3 active:scale-[0.98]',
          isFinalized ? 'border-emerald-800/50' : 'border-zinc-800'
        )}
      >
        <View className="flex-row items-start justify-between">
          <View className="flex-1 mr-3">
            <View className="flex-row items-center gap-2 mb-1">
              {isFinalized && (
                <View className="bg-emerald-600/20 p-1 rounded">
                  <Check size={12} color="#34d399" />
                </View>
              )}
              <Text className="text-white font-semibold text-base" numberOfLines={1}>
                {poll.title}
              </Text>
            </View>

            {isFinalized && finalizedSlot ? (
              <Text className="text-emerald-400 text-sm mt-1">
                {formatSlotDate(finalizedSlot)} at {formatSlotTime(finalizedSlot)}
              </Text>
            ) : (
              <Text className="text-zinc-500 text-sm mt-1">
  {poll.timeSlots.length > 0
    ? `${formatSlotDate(poll.timeSlots[0])} – ${formatSlotDate(
        poll.timeSlots[poll.timeSlots.length - 1]
      )}`
    : 'No dates selected'}
</Text>

            )}

            <View className="flex-row items-center gap-4 mt-3">
              <View className="flex-row items-center gap-1.5">
                <Clock size={14} color="#71717a" />
                <Text className="text-zinc-500 text-xs">
                  {poll.durationMinutes < 60
                    ? `${poll.durationMinutes}m`
                    : `${poll.durationMinutes / 60}h`}
                </Text>
              </View>

              <View className="flex-row items-center gap-1.5">
                <Users size={14} color="#71717a" />
                <Text className="text-zinc-500 text-xs">
                  {respondentCount} {respondentCount === 1 ? 'response' : 'responses'}
                </Text>
              </View>

              <View className="flex-row items-center gap-1.5">
                <Calendar size={14} color="#71717a" />
                <Text className="text-zinc-500 text-xs">
                  {poll.timeSlots.length} slots
                </Text>
              </View>
            </View>
          </View>

          <View className="flex-row items-center gap-2">
            {isCreator && (
              <View className="bg-blue-600/20 px-2 py-0.5 rounded">
                <Text className="text-blue-400 text-xs font-medium">You</Text>
              </View>
            )}
            <ChevronRight size={20} color="#52525b" />
          </View>
        </View>
      </Pressable>
    </Animated.View>
  );
}

export default function HomeScreen() {
  const router = useRouter();
  const { data: polls, isLoading: pollsLoading } = usePolls();
  const { data: user, isLoading: userLoading } = useCurrentUser();

  const currentUserId = user?.id ?? '';
  const isLoading = pollsLoading || userLoading;

  const { myPolls, respondedPolls, openPolls } = useMemo(() => {
    if (!polls || !currentUserId) {
      return { myPolls: [], respondedPolls: [], openPolls: [] };
    }

    const my = polls.filter((p) => p.creatorId === currentUserId);
    const responded = polls.filter(
      (p) =>
        p.creatorId !== currentUserId &&
        p.responses.some((r) => r.sessionId === currentUserId)
    );

    // Sort by most recent first
    const sortByDate = (a: PollWithDetails, b: PollWithDetails) =>
      new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();

    return {
      myPolls: my.sort(sortByDate),
      respondedPolls: responded.sort(sortByDate),
      openPolls: my.filter((p) => p.status === 'open'),
    };
  }, [polls, currentUserId]);

  const handleCreatePoll = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    router.push('/create');
  };

  const handleOpenSettings = () => {
    Haptics.selectionAsync();
    router.push('/settings');
  };

  const handleOpenPoll = (pollId: string) => {
    router.push(`/poll/${pollId}`);
  };

  const hasPolls = myPolls.length > 0 || respondedPolls.length > 0;

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
          className="px-5 pt-4 pb-2"
        >
          <View className="flex-row items-center justify-between">
            <View>
              <Text className="text-white text-2xl font-bold">TimeTogether</Text>
              <Text className="text-zinc-500 text-sm mt-0.5">
                Find the perfect time to meet
              </Text>
            </View>
            <Pressable
              onPress={handleOpenSettings}
              className="w-10 h-10 items-center justify-center rounded-full bg-zinc-800/50"
            >
              <Settings size={20} color="#a1a1aa" />
            </Pressable>
          </View>
        </Animated.View>

        <ScrollView
          className="flex-1"
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{ paddingBottom: 120 }}
        >
          {isLoading ? (
            <View className="flex-1 items-center justify-center mt-20">
              <ActivityIndicator size="large" color="#3b82f6" />
              <Text className="text-zinc-500 mt-4">Loading polls...</Text>
            </View>
          ) : !hasPolls ? (
            // Empty State
            <Animated.View
              entering={FadeIn.delay(200).springify()}
              className="flex-1 items-center justify-center px-8 mt-20"
            >
              <View className="bg-zinc-900 p-6 rounded-full mb-6">
                <Calendar size={48} color="#3b82f6" />
              </View>
              <Text className="text-white text-xl font-semibold text-center mb-2">
                No polls yet
              </Text>
              <Text className="text-zinc-500 text-center leading-relaxed">
                Create your first poll to help your group find the perfect time to meet.
              </Text>
            </Animated.View>
          ) : (
            <View className="px-5 mt-4">
              {/* My Polls */}
              {myPolls.length > 0 && (
                <Animated.View
                  entering={FadeInUp.delay(200).springify()}
                  className="mb-6"
                >
                  <View className="flex-row items-center justify-between mb-3">
                    <Text className="text-zinc-400 text-sm font-medium uppercase tracking-wide">
                      My Polls
                    </Text>
                    <Text className="text-zinc-600 text-xs">
                      {openPolls.length} open
                    </Text>
                  </View>

                  {myPolls.map((poll, index) => (
                    <PollCard
                      key={poll.id}
                      poll={poll}
                      currentUserId={currentUserId}
                      onPress={() => handleOpenPoll(poll.id)}
                      index={index}
                    />
                  ))}
                </Animated.View>
              )}

              {/* Responded Polls */}
              {respondedPolls.length > 0 && (
                <Animated.View
                  entering={FadeInUp.delay(300).springify()}
                  className="mb-6"
                >
                  <Text className="text-zinc-400 text-sm font-medium uppercase tracking-wide mb-3">
                    Responded
                  </Text>

                  {respondedPolls.map((poll, index) => (
                    <PollCard
                      key={poll.id}
                      poll={poll}
                      currentUserId={currentUserId}
                      onPress={() => handleOpenPoll(poll.id)}
                      index={index}
                    />
                  ))}
                </Animated.View>
              )}
            </View>
          )}
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
            className="bg-blue-600 py-4 rounded-2xl items-center active:scale-[0.98] flex-row justify-center gap-2"
          >
            <Plus size={22} color="white" strokeWidth={2.5} />
            <Text className="text-white font-semibold text-lg">
              Create Poll
            </Text>
          </Pressable>
        </Animated.View>
      </SafeAreaView>
    </View>
  );
}
