'use client'

import { useState, useEffect } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { fetchReactions, submitReaction } from '@/lib/api/reactions'
import { getSessionId, getDisplayName } from '@/lib/utils'
import type { Participant } from '@/lib/types'

const PRESET_EMOJIS = ['🎉', '👍', '🙌', '🥳', '😍', '🔥']

interface PollReactionsProps {
  pollId: string
  participants: Participant[]
}

export function PollReactions({ pollId, participants }: PollReactionsProps) {
  const queryClient = useQueryClient()
  const sessionId = typeof window !== 'undefined' ? getSessionId() : ''

  const { data: reactions = [] } = useQuery({
    queryKey: ['reactions', pollId],
    queryFn: () => fetchReactions(pollId),
    staleTime: 10_000,
  })

  const myReaction = reactions.find((r) => r.sessionId === sessionId)

  const [selectedEmoji, setSelectedEmoji] = useState<string | null>(myReaction?.emoji ?? null)
  const [comment, setComment] = useState(myReaction?.comment ?? '')

  // Sync state if myReaction loads after mount
  useEffect(() => {
    if (myReaction) {
      setSelectedEmoji(myReaction.emoji)
      setComment(myReaction.comment ?? '')
    }
  }, [myReaction])

  const mutation = useMutation({
    mutationFn: ({ emoji, comment }: { emoji: string; comment: string }) =>
      submitReaction(pollId, sessionId, emoji, comment || null),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reactions', pollId] })
      setSelectedEmoji(null)
      setComment('')
    },
  })

  const getParticipantName = (sid: string) =>
    participants.find((p) => p.sessionId === sid)?.displayName || getDisplayName() || 'Anonymous'

  return (
    <div className="rounded-xl border border-white/10 bg-white/5 p-4 space-y-4">
      <h3 className="text-sm font-semibold text-text-primary">Reactions</h3>

      {/* Emoji picker */}
      <div className="flex gap-2 flex-wrap">
        {PRESET_EMOJIS.map((emoji) => {
          const isSelected = selectedEmoji === emoji
          return (
            <button
              key={emoji}
              onClick={() => setSelectedEmoji(isSelected ? null : emoji)}
              className={`text-xl p-2 rounded-lg border transition-all ${
                isSelected
                  ? 'border-accent-blue/50 bg-accent-blue/15'
                  : 'border-white/10 bg-white/5 hover:border-white/20'
              }`}
              aria-pressed={isSelected}
              aria-label={`React with ${emoji}`}
            >
              {emoji}
            </button>
          )
        })}
      </div>

      {/* Comment + submit */}
      {selectedEmoji && (
        <div className="space-y-2">
          <input
            type="text"
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            placeholder="Add a comment (optional)"
            maxLength={120}
            className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-text-primary placeholder-text-tertiary outline-none focus:border-accent-blue/50 transition-all"
          />
          <button
            onClick={() => mutation.mutate({ emoji: selectedEmoji, comment })}
            disabled={mutation.isPending}
            className="w-full rounded-lg py-2 text-sm font-semibold bg-accent-blue text-white hover:bg-accent-blue/90 disabled:opacity-50 transition-all"
          >
            {mutation.isPending
              ? 'Posting…'
              : myReaction
              ? 'Update Reaction'
              : 'Post Reaction'}
          </button>
        </div>
      )}

      {/* Existing reactions */}
      {reactions.length > 0 && (
        <div className="space-y-2 pt-2 border-t border-white/10">
          {reactions.map((reaction) => (
            <div key={reaction.id} className="flex items-start gap-3">
              <span className="text-xl leading-none mt-0.5">{reaction.emoji}</span>
              <div>
                <p className="text-xs font-medium text-text-secondary">
                  {getParticipantName(reaction.sessionId)}
                </p>
                {reaction.comment && (
                  <p className="text-sm text-text-primary">{reaction.comment}</p>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
