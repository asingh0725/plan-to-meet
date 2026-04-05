'use client'

import { useMemo, useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  Calendar,
  Clock,
  Users,
  Share2,
  AlertCircle,
  Loader2,
  Check,
  Copy,
  CheckCircle2,
  Lock,
  Sparkles,
} from 'lucide-react'
import { usePoll, useSubmitResponse, useAddParticipant, useIsParticipant, useUserResponses } from '@/lib/hooks'
import { getDisplayName, setDisplayName } from '@/lib/utils'
import { getSlotStats, Availability } from '@/lib/types'
import { TimeSlotCard } from '@/components/TimeSlotCard'
import { NameInput } from '@/components/NameInput'
import { AddToCalendar } from '@/components/AddToCalendar'
import { PollReactions } from '@/components/PollReactions'

interface PollPageClientProps {
  pollId: string
}

export function PollPageClient({ pollId }: PollPageClientProps) {
  const { data: poll, isLoading, isError } = usePoll(pollId)
  const submitResponseMutation = useSubmitResponse()
  const addParticipantMutation = useAddParticipant()

  const [showShareToast, setShowShareToast] = useState(false)
  const [localName, setLocalName] = useState<string | null>(null)

  // Initialize local name from storage
  useEffect(() => {
    setLocalName(getDisplayName())
  }, [])

  const isParticipant = useIsParticipant(poll)
  const userResponses = useUserResponses(poll)
  const responseDeadlinePassed = useMemo(() => {
    if (!poll?.closesAt) return false
    const deadline = new Date(poll.closesAt)
    return !Number.isNaN(deadline.getTime()) && deadline.getTime() <= Date.now()
  }, [poll?.closesAt])
  const formattedDeadline = useMemo(() => {
    if (!poll?.closesAt) return null
    const deadline = new Date(poll.closesAt)
    if (Number.isNaN(deadline.getTime())) return poll.closesAt
    return new Intl.DateTimeFormat(undefined, {
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    }).format(deadline)
  }, [poll?.closesAt])
  const needsName = !isParticipant && !localName && !responseDeadlinePassed

  // Sorted slots by date/time
  const sortedSlots = useMemo(() => {
    if (!poll) return []
    return [...poll.timeSlots].sort((a, b) => {
      const dayCompare = a.day.localeCompare(b.day)
      if (dayCompare !== 0) return dayCompare
      return a.startTime.localeCompare(b.startTime)
    })
  }, [poll])

  // Find best slot
  const bestSlotId = useMemo(() => {
    if (!poll || poll.responses.length === 0) return null

    let bestId: string | null = null
    let bestScore = -Infinity

    for (const slot of poll.timeSlots) {
      const stats = getSlotStats(poll.responses, slot.id)
      if (stats.score > bestScore) {
        bestScore = stats.score
        bestId = slot.id
      }
    }
    return bestId
  }, [poll])

  // Respondent count
  const respondentCount = useMemo(() => {
    if (!poll) return 0
    return new Set(poll.responses.map((r) => r.sessionId)).size
  }, [poll])

  // Finalized slot
  const finalizedSlot = useMemo(() => {
    if (!poll?.finalizedSlotId) return null
    return poll.timeSlots.find((s) => s.id === poll.finalizedSlotId) || null
  }, [poll])

  // Track response completion
  const responseStats = useMemo(() => {
    if (!poll) return { answered: 0, total: 0, isComplete: false }
    const total = poll.timeSlots.length
    const answered = Object.keys(userResponses).length
    return { answered, total, isComplete: answered === total && total > 0 }
  }, [poll, userResponses])

  // Handle name submission
  const handleNameSubmit = async (name: string) => {
    if (responseDeadlinePassed) return
    setDisplayName(name)
    setLocalName(name)

    if (poll) {
      await addParticipantMutation.mutateAsync({
        pollId: poll.id,
        displayName: name,
      })
    }
  }

  // Handle response
  const handleRespond = (slotId: string, availability: Availability) => {
    if (!poll || !localName || responseDeadlinePassed) return

    // If not yet a participant, add them first
    if (!isParticipant) {
      addParticipantMutation.mutate({
        pollId: poll.id,
        displayName: localName,
      })
    }

    submitResponseMutation.mutate({
      pollId: poll.id,
      slotId,
      availability,
    })
  }

  // Handle share
  const handleShare = async () => {
    const shareUrl = `${window.location.origin}/poll/${pollId}`

    try {
      if (navigator.share) {
        await navigator.share({
          title: poll?.title || 'PlanToMeet Poll',
          text: 'Help find a time that works for everyone!',
          url: shareUrl,
        })
      } else {
        await navigator.clipboard.writeText(shareUrl)
        setShowShareToast(true)
        setTimeout(() => setShowShareToast(false), 2000)
      }
    } catch (err) {
      // User cancelled share or copy failed
      try {
        await navigator.clipboard.writeText(shareUrl)
        setShowShareToast(true)
        setTimeout(() => setShowShareToast(false), 2000)
      } catch {
        // Clipboard also failed
      }
    }
  }

  // Loading state
  if (isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center" role="status" aria-label="Loading poll">
        <div className="text-center">
          <Loader2 className="w-8 h-8 text-accent-blue animate-spin mx-auto mb-4" aria-hidden="true" />
          <p className="text-text-secondary">Loading poll...</p>
        </div>
      </div>
    )
  }

  // Error state
  if (isError || !poll) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center p-6">
        <div className="text-center max-w-md">
          <div className="w-16 h-16 rounded-full bg-accent-red/10 flex items-center justify-center mx-auto mb-4">
            <AlertCircle className="w-8 h-8 text-accent-red" />
          </div>
          <h1 className="text-xl font-semibold text-white mb-2">Poll Not Found</h1>
          <p className="text-text-secondary mb-6">
            This poll may have been deleted or the link is incorrect.
          </p>
        </div>
      </div>
    )
  }

  const isFinalized = poll.status === 'finalized'

  return (
    <div className="min-h-screen bg-background">
      {/* Live region for screen readers — announces vote count changes */}
      <div
        aria-live="polite"
        aria-atomic="false"
        className="sr-only"
      >
        {poll.participants.length > 0 &&
          `${poll.participants.length} ${poll.participants.length === 1 ? 'person has' : 'people have'} responded`}
      </div>

      {/* Header */}
      <header className="sticky top-0 z-40 glass border-b border-white/5">
        <div className="max-w-2xl mx-auto px-4 py-4 flex items-center justify-end">

          {!isFinalized && (
            <button
              onClick={handleShare}
              aria-label="Share poll link"
              className="flex items-center gap-2 px-4 py-2 bg-card border border-border rounded-xl text-white hover:bg-card-hover transition-colors"
            >
              <Share2 className="w-4 h-4" aria-hidden="true" />
              <span className="text-sm font-medium">Share</span>
            </button>
          )}
        </div>
      </header>

      <main className="max-w-2xl mx-auto px-4 py-6">
        {/* Poll Info */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-6"
        >
          <h1 className="text-2xl font-bold text-white mb-2">
            {poll.title || 'Untitled Poll'}
          </h1>

          {(poll.isPremium || poll.details || formattedDeadline) && (
            <div className="mb-4 space-y-3">
              <div className="flex flex-wrap gap-2">
                {poll.isPremium && (
                  <div className="inline-flex items-center gap-1.5 rounded-full bg-accent-blue/15 px-3 py-1 text-xs font-semibold text-accent-blue">
                    <Sparkles className="w-3.5 h-3.5" aria-hidden="true" />
                    <span>Premium Event</span>
                  </div>
                )}
                {formattedDeadline && (
                  <div className="inline-flex items-center gap-1.5 rounded-full bg-white/5 px-3 py-1 text-xs font-medium text-text-secondary">
                    <Lock className="w-3.5 h-3.5" aria-hidden="true" />
                    <span>{responseDeadlinePassed ? 'Voting closed' : `Deadline ${formattedDeadline}`}</span>
                  </div>
                )}
              </div>

              {poll.details && (
                <div className="rounded-2xl border border-border bg-card p-4">
                  <p className="text-xs font-semibold uppercase tracking-[0.18em] text-text-tertiary">Organizer Note</p>
                  <p className="mt-2 text-sm leading-6 text-white">{poll.details}</p>
                </div>
              )}
            </div>
          )}

          <div className="flex flex-wrap items-center gap-4 text-sm text-text-secondary">
            <div className="flex items-center gap-1.5">
              <Clock className="w-4 h-4" />
              <span>
                {poll.durationMinutes < 60
                  ? `${poll.durationMinutes} min`
                  : `${Math.floor(poll.durationMinutes / 60)} hour${poll.durationMinutes >= 120 ? 's' : ''}`}
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <Users className="w-4 h-4" />
              <span>
                {respondentCount} {respondentCount === 1 ? 'response' : 'responses'}
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <Calendar className="w-4 h-4" />
              <span>{sortedSlots.length} time slots</span>
            </div>
          </div>
        </motion.div>

        {/* Finalized State */}
        {isFinalized && finalizedSlot && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="mb-6 space-y-4"
          >
            <AddToCalendar poll={poll} slot={finalizedSlot} />
            <PollReactions pollId={poll.id} participants={poll.participants} />
            {poll.isPremium && (
              <div className="rounded-xl border border-accent-blue/20 bg-accent-blue/10 p-4">
                <div className="flex items-start gap-3">
                  <Sparkles className="mt-0.5 h-5 w-5 flex-shrink-0 text-accent-blue" aria-hidden="true" />
                  <div>
                    <p className="text-sm font-semibold text-white">Premium organizer tools live in the iPhone app</p>
                    <p className="mt-1 text-sm text-text-secondary">
                      This event used premium features. Use an Event Pass in the iPhone app to schedule it again with the same premium organizer flow.
                    </p>
                  </div>
                </div>
              </div>
            )}
          </motion.div>
        )}

        {/* Name Input (if needed) */}
        <AnimatePresence mode="wait">
          {needsName && !isFinalized && !responseDeadlinePassed && (
            <motion.div
              key="name-input"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              className="mb-6"
            >
              <NameInput
                onSubmit={handleNameSubmit}
                isLoading={addParticipantMutation.isPending}
              />
            </motion.div>
          )}
        </AnimatePresence>

        {/* Participation Status */}
        {localName && !isFinalized && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="flex items-center gap-2 mb-4 text-sm text-text-secondary"
          >
            <Check className="w-4 h-4 text-accent-green" />
            <span>Voting as <span className="text-white font-medium">{localName}</span></span>
          </motion.div>
        )}

        {/* Completion Banner */}
        <AnimatePresence>
          {responseStats.isComplete && !isFinalized && !responseDeadlinePassed && (
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              className="mb-6 p-4 bg-accent-green/10 border border-accent-green/20 rounded-xl"
            >
              <div className="flex items-start gap-3">
                <CheckCircle2 className="w-5 h-5 text-accent-green flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-white font-medium">Responses submitted!</p>
                  <p className="text-sm text-text-secondary mt-1">
                    You&apos;ve voted on all {responseStats.total} time slots. You can update your responses anytime or close this page.
                  </p>
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {responseDeadlinePassed && !isFinalized && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            className="mb-6 rounded-xl border border-accent-red/20 bg-accent-red/10 p-4"
          >
            <div className="flex items-start gap-3">
              <Lock className="mt-0.5 h-5 w-5 flex-shrink-0 text-accent-red" aria-hidden="true" />
              <div>
                <p className="text-white font-medium">Voting has closed</p>
                <p className="mt-1 text-sm text-text-secondary">
                  {formattedDeadline
                    ? `The organizer closed responses on ${formattedDeadline}. You can still view the poll results below.`
                    : 'The organizer closed responses for this poll. You can still view the poll results below.'}
                </p>
              </div>
            </div>
          </motion.div>
        )}

        {/* Progress indicator */}
        {localName && !isFinalized && !responseDeadlinePassed && !responseStats.isComplete && responseStats.answered > 0 && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="mb-4 text-sm text-text-secondary"
          >
            <span>{responseStats.answered} of {responseStats.total} time slots answered</span>
          </motion.div>
        )}

        {/* Time Slots */}
        {!isFinalized && (
          <div className="mb-4">
            <h2 className="text-sm font-medium text-text-secondary mb-3">
              {responseDeadlinePassed
                ? 'Responses are closed'
                : needsName
                ? 'Available Time Slots'
                : responseStats.isComplete
                ? 'Your responses (tap to update)'
                : 'Tap to vote on each time slot'}
            </h2>
          </div>
        )}

        <div className="space-y-3 pb-20">
          {sortedSlots.map((slot) => (
            <TimeSlotCard
              key={slot.id}
              slot={slot}
              responses={poll.responses}
              userResponse={userResponses[slot.id] || null}
              onRespond={handleRespond}
              isFinalized={isFinalized}
              isBestOption={slot.id === bestSlotId}
              isSelected={poll.finalizedSlotId === slot.id}
              disabled={needsName || submitResponseMutation.isPending || responseDeadlinePassed}
            />
          ))}
        </div>
      </main>

      {/* Share Toast */}
      <AnimatePresence>
        {showShareToast && (
          <motion.div
            initial={{ opacity: 0, y: 50 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 50 }}
            className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50"
          >
            <div className="flex items-center gap-2 px-4 py-3 bg-card border border-border rounded-xl shadow-lg">
              <Copy className="w-4 h-4 text-accent-green" />
              <span className="text-sm text-white">Link copied to clipboard!</span>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
