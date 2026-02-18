'use client'

import { memo } from 'react'
import { motion } from 'framer-motion'
import { Check, HelpCircle, X, Trophy } from 'lucide-react'
import { cn, formatSlotDate, formatSlotTime } from '@/lib/utils'
import { TimeSlot, Response, Availability, getSlotStats } from '@/lib/types'

interface TimeSlotCardProps {
  slot: TimeSlot
  responses: Response[]
  userResponse: Availability | null
  onRespond: (slotId: string, availability: Availability) => void
  isFinalized: boolean
  isBestOption: boolean
  isSelected: boolean
  disabled?: boolean
}

export const TimeSlotCard = memo(function TimeSlotCard({
  slot,
  responses,
  userResponse,
  onRespond,
  isFinalized,
  isBestOption,
  isSelected,
  disabled,
}: TimeSlotCardProps) {
  const stats = getSlotStats(responses, slot.id)
  const slotLabel = `${formatSlotDate(slot)} at ${formatSlotTime(slot)}`

  const handleVote = (availability: Availability) => {
    if (!disabled && !isFinalized) {
      onRespond(slot.id, availability)
    }
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      role="group"
      aria-label={`Time slot: ${slotLabel}${isSelected ? ', finalized' : ''}`}
      className={cn(
        'bg-card border rounded-2xl p-4 transition-all',
        isSelected
          ? 'border-accent-green bg-accent-green/5 glow-green'
          : isBestOption && !isFinalized
          ? 'border-accent-blue/50'
          : 'border-border hover:border-border-light'
      )}
    >
      {/* Header */}
      <div className="flex items-center justify-between mb-3">
        <div>
          <p className="text-white font-semibold">{formatSlotDate(slot)}</p>
          <p className="text-text-secondary text-sm mt-0.5">
            {formatSlotTime(slot)}
          </p>
        </div>

        {isSelected && (
          <div className="flex items-center gap-1.5 px-3 py-1 bg-accent-green rounded-full">
            <Check className="w-3.5 h-3.5 text-white" />
            <span className="text-xs font-semibold text-white">Selected</span>
          </div>
        )}

        {isBestOption && !isFinalized && !isSelected && (
          <div className="flex items-center gap-1.5 px-3 py-1 bg-accent-blue/20 rounded-full">
            <Trophy className="w-3.5 h-3.5 text-accent-blue" />
            <span className="text-xs font-medium text-accent-blue">Best</span>
          </div>
        )}
      </div>

      {/* Stats */}
      {stats.total > 0 && (
        <div className="flex items-center gap-4 mb-3">
          <div className="flex items-center gap-1.5">
            <div className="w-2 h-2 rounded-full bg-accent-green" />
            <span className="text-text-secondary text-xs">{stats.available} yes</span>
          </div>
          <div className="flex items-center gap-1.5">
            <div className="w-2 h-2 rounded-full bg-accent-orange" />
            <span className="text-text-secondary text-xs">{stats.maybe} maybe</span>
          </div>
          <div className="flex items-center gap-1.5">
            <div className="w-2 h-2 rounded-full bg-accent-red" />
            <span className="text-text-secondary text-xs">{stats.unavailable} no</span>
          </div>
        </div>
      )}

      {/* Vote Buttons */}
      {!isFinalized && (
        <div className="flex gap-2" role="group" aria-label={`Vote for ${slotLabel}`}>
          <VoteButton
            type="available"
            isActive={userResponse === 'available'}
            onClick={() => handleVote('available')}
            disabled={disabled}
            slotLabel={slotLabel}
          />
          <VoteButton
            type="maybe"
            isActive={userResponse === 'maybe'}
            onClick={() => handleVote('maybe')}
            disabled={disabled}
            slotLabel={slotLabel}
          />
          <VoteButton
            type="unavailable"
            isActive={userResponse === 'unavailable'}
            onClick={() => handleVote('unavailable')}
            disabled={disabled}
            slotLabel={slotLabel}
          />
        </div>
      )}
    </motion.div>
  )
})

interface VoteButtonProps {
  type: Availability
  isActive: boolean
  onClick: () => void
  disabled?: boolean
  slotLabel: string
}

function VoteButton({ type, isActive, onClick, disabled, slotLabel }: VoteButtonProps) {
  const config = {
    available: {
      icon: Check,
      label: 'Yes',
      activeClass: 'bg-accent-green border-accent-green text-white',
    },
    maybe: {
      icon: HelpCircle,
      label: 'Maybe',
      activeClass: 'bg-accent-orange border-accent-orange text-white',
    },
    unavailable: {
      icon: X,
      label: 'No',
      activeClass: 'bg-accent-red border-accent-red text-white',
    },
  }

  const { icon: Icon, label, activeClass } = config[type]

  const stateHint = isActive ? ` (currently selected)` : ''
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      aria-label={`${label} for ${slotLabel}${stateHint}`}
      aria-pressed={isActive}
      className={cn(
        'flex-1 flex items-center justify-center gap-2 py-3 rounded-xl border transition-all',
        'disabled:opacity-50 disabled:cursor-not-allowed',
        isActive
          ? activeClass
          : 'bg-background border-border text-text-secondary hover:bg-card-hover hover:text-white'
      )}
    >
      <Icon className="w-4 h-4" aria-hidden="true" />
      <span className="font-medium text-sm">{label}</span>
    </button>
  )
}
