'use client'

import { useCallback, useEffect, useId, useRef, useState } from 'react'
import { motion } from 'framer-motion'
import {
  Apple,
  ArrowRight,
  CalendarCheck,
  CheckCircle2,
  ChevronRight,
  Clock,
  MessageSquare,
  Sparkles,
  Users,
  Zap,
  ShieldCheck,
  type LucideIcon,
} from 'lucide-react'
import Image from 'next/image'
import Link from 'next/link'

const APP_STORE_URL = 'https://apps.apple.com/app/plantomeet'

const FEATURE_RAIL = [
  { icon: MessageSquare, label: 'iMessage poll' },
  { icon: Zap, label: 'App Clip vote' },
  { icon: Users, label: 'Group decisions' },
  { icon: CalendarCheck, label: 'Calendar ready' },
  { icon: Clock, label: 'Time windows' },
  { icon: ShieldCheck, label: 'Private by design' },
]

type Clip = {
  id: string
  title: string
  subtitle: string
  video: string
  poster: string
}

const FLOW_CLIPS: Clip[] = [
  {
    id: 'tap',
    title: 'Step 1',
    subtitle: 'Tap PlanToMeet',
    video: '/hero-media/trimmed/01-tap-on-plantomeet.mp4',
    poster: '/hero-media/posters/01-tap-on-plantomeet.jpg',
  },
  {
    id: 'create',
    title: 'Step 2',
    subtitle: 'Create the poll',
    video: '/hero-media/trimmed/02-create-poll.mp4',
    poster: '/hero-media/posters/02-create-poll.jpg',
  },
  {
    id: 'respond',
    title: 'Step 3',
    subtitle: 'Respond in App Clip',
    video: '/hero-media/trimmed/04-respond-to-poll.mp4',
    poster: '/hero-media/posters/04-respond-to-poll.jpg',
  },
  {
    id: 'finalize',
    title: 'Step 4',
    subtitle: 'Finalize results',
    video: '/hero-media/trimmed/03-confirm-poll.mp4',
    poster: '/hero-media/posters/03-confirm-poll.jpg',
  },
  {
    id: 'calendar',
    title: 'Step 5',
    subtitle: 'Add to calendar',
    video: '/hero-media/trimmed/05-add-to-calendar.mp4',
    poster: '/hero-media/posters/05-add-to-calendar.jpg',
  },
]

const FLOW_STEPS = [
  {
    title: 'Create inside iMessage',
    description: 'Start a poll where the conversation already lives.',
  },
  {
    title: 'Guests vote instantly',
    description: 'App Clip opens in seconds with zero download friction.',
  },
  {
    title: 'Best time rises fast',
    description: 'Consensus is visible without endless back and forth.',
  },
  {
    title: 'Confirm and sync',
    description: 'Lock it in and push to every calendar with one tap.',
  },
]

const DECISION_NODES = [
  { label: 'iMessage', position: 'md:left-0 md:top-6' },
  { label: 'App Clip', position: 'md:right-0 md:top-10' },
  { label: 'Guests', position: 'md:left-10 md:bottom-6' },
  { label: 'Calendar', position: 'md:right-10 md:bottom-8' },
  { label: 'Notifications', position: 'md:left-1/2 md:top-0 md:-translate-x-1/2' },
  { label: 'Reminders', position: 'md:left-1/2 md:bottom-0 md:-translate-x-1/2' },
]

function Navigation() {
  const [scrolled, setScrolled] = useState(false)

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 12)
    }
    window.addEventListener('scroll', handleScroll)
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  return (
    <motion.header
      initial={{ y: -20, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.6, ease: 'easeOut' }}
      className="fixed inset-x-0 top-0 z-50 px-4 pt-4"
    >
      <nav
        className={`mx-auto flex max-w-6xl items-center justify-between rounded-full px-4 py-2.5 transition-all duration-300 md:px-6 ${
          scrolled
            ? 'border border-white/10 bg-white/5 shadow-soft backdrop-blur-xl'
            : 'bg-transparent'
        }`}
      >
        <Link href="/" className="flex items-center gap-3">
          <div className="relative">
            <div className="absolute -inset-1 rounded-2xl bg-gradient-to-br from-accent-blue/40 to-accent-violet/40 blur-lg" />
            <Image
              src="/icon-192.png"
              alt="PlanToMeet"
              width={36}
              height={36}
              className="relative rounded-2xl border border-white/20 bg-[#0A0F1B]"
            />
          </div>
          <span className="font-display text-lg font-semibold text-text-primary">PlanToMeet</span>
        </Link>

        <div className="hidden items-center gap-8 md:flex">
          <a href="#features" className="text-sm font-medium text-text-secondary transition hover:text-text-primary">
            Features
          </a>
          <a href="#flow" className="text-sm font-medium text-text-secondary transition hover:text-text-primary">
            Flow
          </a>
          <a href="#engine" className="text-sm font-medium text-text-secondary transition hover:text-text-primary">
            Engine
          </a>
        </div>

        <a
          href={APP_STORE_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="group flex h-10 items-center gap-2 rounded-full border border-white/15 bg-white/5 px-5 text-sm font-semibold text-text-primary transition hover:border-white/30"
        >
          <Apple className="h-4 w-4" />
          <span className="hidden sm:inline">Get started</span>
          <ChevronRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
        </a>
      </nav>
    </motion.header>
  )
}

function HeroGridOverlay() {
  return (
    <svg
      className="absolute inset-0 h-full w-full opacity-70"
      viewBox="0 0 1200 700"
      preserveAspectRatio="xMidYMid slice"
    >
      <defs>
        <pattern id="hero-grid" width="160" height="160" patternUnits="userSpaceOnUse">
          <path
            d="M160 0H0V160"
            fill="none"
            stroke="rgba(148, 163, 184, 0.12)"
            strokeWidth="1"
          />
          <path
            d="M80 74h12M86 68v12"
            stroke="rgba(226, 232, 240, 0.35)"
            strokeWidth="1"
          />
          <circle cx="80" cy="80" r="1.5" fill="rgba(226, 232, 240, 0.5)" />
          <circle cx="0" cy="0" r="1" fill="rgba(226, 232, 240, 0.3)" />
          <circle cx="40" cy="40" r="0.8" fill="rgba(226, 232, 240, 0.25)" />
          <circle cx="120" cy="120" r="0.8" fill="rgba(226, 232, 240, 0.25)" />
        </pattern>
        <radialGradient id="heroGlow" cx="50%" cy="20%" r="60%">
          <stop offset="0%" stopColor="rgba(126, 166, 255, 0.35)" />
          <stop offset="100%" stopColor="rgba(5, 7, 12, 0)" />
        </radialGradient>
      </defs>
      <rect width="100%" height="100%" fill="url(#hero-grid)" />
      <rect width="100%" height="100%" fill="url(#heroGlow)" />
    </svg>
  )
}

function CircuitBoardLayer({
  className = '',
  idPrefix = 'pcb',
}: {
  className?: string
  idPrefix?: string
}) {
  const instanceId = useId().replace(/:/g, '')
  const prefix = `${idPrefix}-${instanceId}`

  return (
    <svg
      className={`absolute inset-0 h-full w-full ${className}`}
      viewBox="0 0 1200 600"
      preserveAspectRatio="xMidYMid slice"
    >
      <defs>
        <pattern id={`${prefix}-grid`} width="120" height="120" patternUnits="userSpaceOnUse">
          <path
            d="M120 0H0V120"
            fill="none"
            stroke="rgba(148, 163, 184, 0.08)"
            strokeWidth="1"
          />
          <path d="M60 52h12M66 46v12" stroke="rgba(226, 232, 240, 0.25)" strokeWidth="1" />
          <circle cx="60" cy="60" r="1.5" fill="rgba(226, 232, 240, 0.35)" />
        </pattern>
        <pattern id={`${prefix}-dots`} width="60" height="60" patternUnits="userSpaceOnUse">
          <circle cx="10" cy="10" r="1" fill="rgba(148, 163, 184, 0.2)" />
          <circle cx="50" cy="20" r="1" fill="rgba(148, 163, 184, 0.15)" />
          <circle cx="30" cy="50" r="1" fill="rgba(148, 163, 184, 0.18)" />
        </pattern>
        <linearGradient id={`${prefix}-chip`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="rgba(126, 166, 255, 0.45)" />
          <stop offset="100%" stopColor="rgba(127, 231, 255, 0.1)" />
        </linearGradient>
        <linearGradient id={`${prefix}-trace`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="rgba(127, 231, 255, 0.35)" />
          <stop offset="100%" stopColor="rgba(126, 166, 255, 0.1)" />
        </linearGradient>
        <filter id={`${prefix}-glow`} x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="2.4" result="blur" />
          <feMerge>
            <feMergeNode in="blur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>
      <rect width="100%" height="100%" fill={`url(#${prefix}-grid)`} />
      <rect width="100%" height="100%" fill={`url(#${prefix}-dots)`} />

      <g stroke="rgba(148, 163, 184, 0.2)" strokeWidth="1" fill="none">
        <path d="M80 120H320V200H420" />
        <path d="M1120 120H880V200H780" />
        <path d="M140 420H340V320H460" />
        <path d="M1060 420H860V320H740" />
        <path d="M240 70H240V160H340" />
        <path d="M960 70H960V160H860" />
        <path d="M160 280H260V360H420" />
        <path d="M1040 280H940V360H780" />
        <path d="M420 460H560V520H700" />
        <path d="M780 140H640V80H520" />
      </g>

      <g filter={`url(#${prefix}-glow)`}>
        <path
          className="circuit-flow"
          d="M140 240H360V200H520"
          stroke={`url(#${prefix}-trace)`}
          strokeWidth="1.5"
          fill="none"
        />
        <path
          className="circuit-flow-slow"
          d="M1060 240H840V200H680"
          stroke={`url(#${prefix}-trace)`}
          strokeWidth="1.5"
          fill="none"
        />
        <path
          className="circuit-flow"
          d="M360 380H520V320H620"
          stroke={`url(#${prefix}-trace)`}
          strokeWidth="1.5"
          fill="none"
        />
        <path
          className="circuit-flow-slow"
          d="M840 380H680V320H580"
          stroke={`url(#${prefix}-trace)`}
          strokeWidth="1.5"
          fill="none"
        />
      </g>

      <g fill="rgba(148, 163, 184, 0.2)">
        <rect x="180" y="210" width="70" height="46" rx="10" />
        <rect x="950" y="210" width="70" height="46" rx="10" />
        <rect x="460" y="120" width="180" height="100" rx="18" fill={`url(#${prefix}-chip)`} />
        <rect x="460" y="360" width="180" height="80" rx="18" fill="rgba(148,163,184,0.18)" />
        <rect x="680" y="260" width="110" height="60" rx="14" />
      </g>

      <g fill="rgba(127,231,255,0.55)" filter={`url(#${prefix}-glow)`}>
        <circle className="circuit-dot" cx="420" cy="200" r="2.5" />
        <circle className="circuit-dot" cx="780" cy="200" r="2.5" />
        <circle className="circuit-dot" cx="460" cy="320" r="2.5" />
        <circle className="circuit-dot" cx="740" cy="320" r="2.5" />
        <circle className="circuit-dot" cx="580" cy="520" r="2" />
      </g>
    </svg>
  )
}

function EngineCircuitBackdrop() {
  const instanceId = useId().replace(/:/g, '')
  const prefix = `engine-${instanceId}`

  return (
    <svg
      className="pointer-events-none absolute inset-0 h-full w-full opacity-80"
      viewBox="0 0 1200 520"
      preserveAspectRatio="xMidYMid slice"
    >
      <defs>
        <linearGradient id={`${prefix}-trace`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="rgba(135, 220, 255, 0.55)" />
          <stop offset="100%" stopColor="rgba(126, 166, 255, 0.18)" />
        </linearGradient>
        <linearGradient id={`${prefix}-chip`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="rgba(126, 166, 255, 0.5)" />
          <stop offset="60%" stopColor="rgba(127, 231, 255, 0.3)" />
          <stop offset="100%" stopColor="rgba(10, 15, 27, 0.1)" />
        </linearGradient>
        <radialGradient id={`${prefix}-chipGlow`} cx="50%" cy="50%" r="60%">
          <stop offset="0%" stopColor="rgba(135, 220, 255, 0.55)" />
          <stop offset="70%" stopColor="rgba(126, 166, 255, 0.15)" />
          <stop offset="100%" stopColor="rgba(10, 15, 27, 0)" />
        </radialGradient>
        <pattern id={`${prefix}-pads`} width="46" height="46" patternUnits="userSpaceOnUse">
          <rect x="5" y="5" width="6" height="6" rx="2" fill="rgba(148,163,184,0.25)" />
          <rect x="30" y="12" width="4" height="4" rx="1" fill="rgba(148,163,184,0.18)" />
          <rect x="18" y="32" width="5" height="5" rx="1.5" fill="rgba(148,163,184,0.2)" />
        </pattern>
        <filter id={`${prefix}-glow`} x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="2.2" result="blur" />
          <feMerge>
            <feMergeNode in="blur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        <filter id={`${prefix}-chipFilter`} x="-40%" y="-40%" width="180%" height="180%">
          <feGaussianBlur stdDeviation="10" result="blur" />
          <feMerge>
            <feMergeNode in="blur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      <rect width="100%" height="100%" fill={`url(#${prefix}-pads)`} opacity="0.5" />

      <g stroke="rgba(148, 163, 184, 0.18)" strokeWidth="1" fill="none">
        <path d="M120 120H320V200H420" />
        <path d="M1080 120H880V200H780" />
        <path d="M160 400H360V320H460" />
        <path d="M1040 400H840V320H740" />
        <path d="M420 70H420V160H520" />
        <path d="M780 70H780V160H680" />
        <path d="M420 450H420V360H520" />
        <path d="M780 450H780V360H680" />
        <path d="M260 180H260V260H360" />
        <path d="M940 180H940V260H840" />
        <path d="M260 340H260V420H360" />
        <path d="M940 340H940V420H840" />
        <path d="M360 120H360V80H520" />
        <path d="M840 120H840V80H680" />
      </g>

      <g filter={`url(#${prefix}-glow)`}>
        <path
          className="circuit-flow"
          d="M200 260H420V200H520"
          stroke={`url(#${prefix}-trace)`}
          strokeWidth="1.6"
          fill="none"
        />
        <path
          className="circuit-flow-slow"
          d="M1000 260H780V200H680"
          stroke={`url(#${prefix}-trace)`}
          strokeWidth="1.6"
          fill="none"
        />
        <path
          className="circuit-flow"
          d="M340 360H520V300H620"
          stroke={`url(#${prefix}-trace)`}
          strokeWidth="1.6"
          fill="none"
        />
        <path
          className="circuit-flow-slow"
          d="M860 360H680V300H580"
          stroke={`url(#${prefix}-trace)`}
          strokeWidth="1.6"
          fill="none"
        />
        <path
          className="circuit-flow"
          d="M420 200H520V150H680"
          stroke={`url(#${prefix}-trace)`}
          strokeWidth="1.4"
          fill="none"
        />
        <path
          className="circuit-flow-slow"
          d="M780 320H700V380H520"
          stroke={`url(#${prefix}-trace)`}
          strokeWidth="1.4"
          fill="none"
        />
      </g>

      <g fill="rgba(148, 163, 184, 0.2)">
        <rect x="460" y="140" width="280" height="220" rx="26" fill={`url(#${prefix}-chip)`} />
        <rect x="500" y="180" width="200" height="140" rx="20" fill="rgba(10,15,27,0.65)" />
        <rect x="170" y="190" width="90" height="56" rx="12" />
        <rect x="940" y="190" width="90" height="56" rx="12" />
        <rect x="250" y="330" width="90" height="56" rx="12" />
        <rect x="860" y="330" width="90" height="56" rx="12" />
        <rect x="360" y="210" width="42" height="22" rx="6" />
        <rect x="798" y="210" width="42" height="22" rx="6" />
        <rect x="360" y="300" width="42" height="22" rx="6" />
        <rect x="798" y="300" width="42" height="22" rx="6" />
      </g>

      <g filter={`url(#${prefix}-chipFilter)`}>
        <circle cx="600" cy="250" r="140" fill={`url(#${prefix}-chipGlow)`} />
      </g>

      <g fill="rgba(127,231,255,0.5)" filter={`url(#${prefix}-glow)`}>
        <circle className="circuit-dot" cx="420" cy="210" r="2.4" />
        <circle className="circuit-dot" cx="780" cy="210" r="2.4" />
        <circle className="circuit-dot" cx="460" cy="320" r="2.4" />
        <circle className="circuit-dot" cx="740" cy="320" r="2.4" />
        <circle className="circuit-dot" cx="600" cy="150" r="2" />
        <circle className="circuit-dot" cx="600" cy="350" r="2" />
      </g>
    </svg>
  )
}

function GlassCard({
  title,
  subtitle,
  className,
  children,
}: {
  title: string
  subtitle: string
  className?: string
  children: React.ReactNode
}) {
  return (
    <div
      className={`relative rounded-3xl border border-white/15 bg-[#0B111B]/70 p-6 shadow-[0_40px_120px_-70px_rgba(8,12,22,0.9)] backdrop-blur-2xl ${className || ''}`}
    >
      <div className="pointer-events-none absolute -inset-8 rounded-[32px] bg-gradient-to-br from-accent-blue/25 via-accent-violet/10 to-transparent blur-3xl opacity-80" />
      <div className="pointer-events-none absolute inset-0 rounded-3xl bg-gradient-to-br from-white/12 via-white/6 to-transparent" />
      <div className="pointer-events-none absolute inset-0 rounded-3xl border border-white/20" />
      <div className="pointer-events-none absolute inset-[1px] rounded-[22px] border border-white/10" />
      <div className="pointer-events-none absolute inset-0 rounded-3xl edge-shine" />
      <div className="pointer-events-none absolute left-5 top-5 h-1.5 w-1.5 rounded-full bg-white/40" />
      <div className="pointer-events-none absolute right-5 top-5 h-1.5 w-1.5 rounded-full bg-white/30" />
      <div className="pointer-events-none absolute left-5 bottom-5 h-1.5 w-1.5 rounded-full bg-white/20" />
      <div className="pointer-events-none absolute right-5 bottom-5 h-1.5 w-1.5 rounded-full bg-white/25" />
      <div className="relative z-10">
        <div className="flex items-start justify-between gap-3">
          <div>
            <p className="text-sm font-semibold text-text-primary">{title}</p>
            <p className="text-xs text-text-tertiary">{subtitle}</p>
          </div>
          <div className="h-8 w-8 rounded-2xl border border-white/15 bg-white/5" />
        </div>
        <div className="mt-4 space-y-3 text-sm text-text-secondary">
          {children}
        </div>
      </div>
    </div>
  )
}

function HeroCardStack() {
  return (
    <div className="relative mx-auto grid max-w-5xl gap-6 md:grid-cols-3">
      <div className="pointer-events-none absolute -inset-12 rounded-[40px] bg-gradient-to-br from-accent-blue/25 via-accent-violet/15 to-transparent blur-3xl opacity-80" />
      <motion.div className="relative">
        <GlassCard title="Friday Dinner" subtitle="Poll created in iMessage">
          <div className="flex items-center justify-between rounded-xl border border-white/15 bg-white/10 px-3 py-2 shadow-[inset_0_1px_0_rgba(255,255,255,0.18)]">
            <span>Fri 7:30 PM</span>
            <span className="text-xs text-accent-teal">6 free</span>
          </div>
          <div className="flex items-center justify-between rounded-xl border border-white/15 bg-white/10 px-3 py-2 shadow-[inset_0_1px_0_rgba(255,255,255,0.18)]">
            <span>Sat 6:00 PM</span>
            <span className="text-xs text-text-tertiary">3 free</span>
          </div>
          <div className="flex items-center gap-2 text-xs text-text-tertiary">
            <span className="h-2 w-2 rounded-full bg-accent-teal" />
            Consensus building
          </div>
        </GlassCard>
      </motion.div>

      <motion.div className="relative">
        <GlassCard title="Vote in App Clip" subtitle="No install required">
          <div className="flex items-center justify-between rounded-xl border border-white/15 bg-white/10 px-3 py-2 shadow-[inset_0_1px_0_rgba(255,255,255,0.18)]">
            <span>Alex</span>
            <span className="text-xs text-accent-cyan">Free</span>
          </div>
          <div className="flex items-center justify-between rounded-xl border border-white/15 bg-white/10 px-3 py-2 shadow-[inset_0_1px_0_rgba(255,255,255,0.18)]">
            <span>Jordan</span>
            <span className="text-xs text-text-tertiary">Maybe</span>
          </div>
          <div className="flex items-center justify-between rounded-xl border border-white/15 bg-white/10 px-3 py-2 shadow-[inset_0_1px_0_rgba(255,255,255,0.18)]">
            <span>Taylor</span>
            <span className="text-xs text-text-tertiary">Busy</span>
          </div>
        </GlassCard>
      </motion.div>

      <motion.div className="relative">
        <GlassCard title="Best Time" subtitle="Auto-ranked by responses">
          <div className="flex items-center justify-between rounded-xl border border-white/15 bg-white/10 px-3 py-2 shadow-[inset_0_1px_0_rgba(255,255,255,0.18)]">
            <span>Fri 7:30 PM</span>
            <span className="text-xs text-accent-blue">Top pick</span>
          </div>
          <div className="flex items-center gap-2 text-xs text-text-tertiary">
            <CheckCircle2 className="h-4 w-4 text-accent-blue" />
            Ready to send to calendar
          </div>
        </GlassCard>
      </motion.div>
    </div>
  )
}

function Hero() {
  return (
    <section className="relative overflow-hidden bg-background pt-32 pb-24">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute inset-0 bg-auth-stars opacity-70" />
        <div className="absolute inset-0 bg-auth-grid opacity-25" />
        <div className="absolute inset-0 bg-auth-radial" />
        <CircuitBoardLayer className="opacity-40" idPrefix="hero-pcb" />
        <div className="absolute inset-0 bg-auth-noise opacity-25 mix-blend-soft-light" />
        <div className="absolute inset-0 bg-auth-vignette opacity-80" />
        <div className="absolute inset-x-0 top-0 h-40 bg-gradient-to-b from-[#05070C] to-transparent" />
        <HeroGridOverlay />
      </div>

      <div className="relative z-10 px-6">
        <div className="mx-auto max-w-5xl text-center">
          <div className="flex items-center justify-center gap-4">
            <span className="h-px w-12 bg-white/15" />
            <div className="inline-flex items-center gap-2 rounded-full border border-white/12 bg-white/5 px-4 py-2 text-xs font-semibold uppercase tracking-[0.22em] text-text-tertiary">
              <Sparkles className="h-4 w-4 text-accent-cyan" />
              Introducing
            </div>
            <span className="h-px w-12 bg-white/15" />
          </div>

          <motion.h1
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="mt-6 font-display text-[clamp(3rem,8vw,6.2rem)] font-semibold leading-[1.05] tracking-tight text-transparent bg-clip-text bg-[linear-gradient(110deg,#F8FAFF_0%,#D7E4FF_35%,#9DB8FF_50%,#F8FAFF_62%,#7EA6FF_100%)] text-auth-soft text-auth-glow hero-shimmer"
          >
            PlanToMeet
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="mx-auto mt-4 max-w-2xl text-lg text-text-secondary/90"
          >
            The fastest way to decide a time in group chat. Create polls inside iMessage,
            let guests vote instantly, and lock the winning slot.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="mt-8 flex flex-wrap justify-center gap-4"
          >
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="group flex h-14 items-center gap-3 rounded-full bg-accent-blue px-8 text-base font-semibold text-[#05070C] shadow-medium transition hover:shadow-elevated"
            >
              <Apple className="h-5 w-5" />
              Download for iOS
              <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" />
            </a>
            <a
              href="#flow"
              className="flex h-14 items-center gap-2 rounded-full border border-white/15 bg-white/5 px-8 text-base font-medium text-text-primary transition hover:border-white/30"
            >
              See the flow
              <ArrowRight className="h-4 w-4" />
            </a>
          </motion.div>
        </div>

        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.3 }}
          className="mx-auto mt-16 max-w-5xl"
        >
          <HeroCardStack />
        </motion.div>
      </div>
    </section>
  )
}

function FeatureChip({
  icon: Icon,
  label,
  index,
}: {
  icon: LucideIcon
  label: string
  index: number
}) {
  return (
    <motion.div
      className="group relative flex flex-col items-center gap-3"
      style={{ transformStyle: 'preserve-3d' }}
      whileHover={{
        y: -6,
        rotateX: 12,
        rotateY: index % 2 === 0 ? -10 : 10,
        scale: 1.05,
      }}
      transition={{ type: 'spring', stiffness: 180, damping: 14 }}
    >
      <div className="relative flex h-14 w-14 items-center justify-center rounded-2xl border border-white/18 bg-[#0A0F1B]/70 shadow-[0_14px_35px_-20px_rgba(8,12,24,0.9)]">
        <span className="pointer-events-none absolute -inset-2 rounded-[20px] bg-gradient-to-br from-accent-blue/30 via-accent-violet/10 to-transparent blur-2xl opacity-0 transition group-hover:opacity-70" />
        <span className="pointer-events-none absolute inset-0 rounded-2xl bg-gradient-to-br from-white/16 via-white/5 to-transparent" />
        <span className="pointer-events-none absolute inset-0 rounded-2xl border border-white/20" />
        <span className="pointer-events-none absolute inset-0 rounded-2xl edge-shine" />
        <Icon className="relative z-10 h-5 w-5 text-accent-ice" style={{ transform: 'translateZ(18px)' }} />
      </div>
      <span className="text-xs font-medium text-text-tertiary">{label}</span>
    </motion.div>
  )
}

function FeatureRail() {
  return (
    <section id="features" className="relative bg-background py-16">
      <div className="absolute inset-0 bg-gradient-to-b from-transparent via-white/5 to-transparent" />
      <div className="absolute inset-0 bg-auth-noise opacity-20 mix-blend-soft-light" />
      <div className="relative mx-auto max-w-6xl px-6">
        <div className="relative">
          <div className="pointer-events-none absolute left-6 right-6 top-7 hidden h-px bg-white/10 md:block" />
          <div className="pointer-events-none absolute left-6 right-6 top-7 hidden items-center justify-between md:flex">
            {FEATURE_RAIL.map((item) => (
              <span
                key={`${item.label}-dot`}
                className="h-2 w-2 rounded-full border border-white/20 bg-white/10 shadow-[0_0_12px_rgba(126,166,255,0.3)]"
              />
            ))}
          </div>
          <div className="flex flex-wrap items-start justify-center gap-10 md:flex-nowrap md:justify-between">
            {FEATURE_RAIL.map((item, index) => (
              <FeatureChip key={item.label} icon={item.icon} label={item.label} index={index} />
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}

function DeviceFrame({ children }: { children: React.ReactNode }) {
  return (
    <div className="relative">
      <div className="absolute -left-1 top-24 hidden h-12 w-1 rounded-full bg-[#1C2232] md:block" />
      <div className="absolute -left-1 top-40 hidden h-8 w-1 rounded-full bg-[#1C2232] md:block" />
      <div className="absolute -right-1 top-32 hidden h-16 w-1 rounded-full bg-[#1C2232] md:block" />

      <div className="relative rounded-[48px] bg-gradient-to-b from-[#1C2232] via-[#0B0F17] to-[#05070C] p-3 shadow-elevated">
        <div className="absolute inset-0 rounded-[48px] border border-white/10" />
        <div className="relative rounded-[40px] border border-white/5 bg-black p-1.5">
          <div className="absolute inset-x-0 top-2.5 z-10 flex justify-center">
            <div className="h-6 w-28 rounded-full bg-black" />
          </div>
          <div className="relative overflow-hidden rounded-[34px] bg-black">
            {children}
          </div>
        </div>
      </div>
    </div>
  )
}

function FlowCarousel() {
  const [activeIndex, setActiveIndex] = useState(0)
  const videoRefs = useRef<(HTMLVideoElement | null)[]>([])
  const advanceLockRef = useRef(false)

  const advance = useCallback(() => {
    if (advanceLockRef.current) return
    advanceLockRef.current = true
    setActiveIndex((prev) => (prev + 1) % FLOW_CLIPS.length)
  }, [])

  useEffect(() => {
    videoRefs.current.forEach((video, index) => {
      if (!video) return
      if (index === activeIndex) {
        advanceLockRef.current = false
        video.currentTime = 0
        const playPromise = video.play()
        if (playPromise) {
          playPromise.catch(() => undefined)
        }
      } else {
        video.pause()
      }
    })
  }, [activeIndex])

  return (
    <div className="relative">
      <div className="mb-6 flex flex-wrap justify-center gap-2">
        {FLOW_CLIPS.map((clip, index) => (
          <button
            key={clip.id}
            onClick={() => setActiveIndex(index)}
            className={`flex items-center gap-2 rounded-full px-4 py-2 text-xs font-medium transition-all ${
              index === activeIndex
                ? 'bg-accent-blue text-[#05070C] shadow-soft'
                : 'border border-white/10 bg-white/5 text-text-tertiary hover:text-text-primary'
            }`}
          >
            <span className="hidden sm:inline text-[11px] uppercase tracking-[0.18em]">
              {clip.title}
            </span>
            <span className={index === activeIndex ? 'text-[#05070C]' : 'text-text-primary'}>{clip.subtitle}</span>
          </button>
        ))}
      </div>

      <div className="flex justify-center">
        <DeviceFrame>
          <div className="relative aspect-[390/844] w-[260px] overflow-hidden sm:w-[300px]">
            {FLOW_CLIPS.map((clip, index) => (
              <motion.div
                key={clip.id}
                initial={false}
                animate={{
                  opacity: index === activeIndex ? 1 : 0,
                  scale: index === activeIndex ? 1 : 0.95,
                }}
                transition={{ duration: 0.4 }}
                className="absolute inset-0"
              >
                <video
                  ref={(el) => {
                    videoRefs.current[index] = el
                  }}
                  muted
                  playsInline
                  preload="metadata"
                  poster={clip.poster}
                  className="h-full w-full object-cover"
                  onTimeUpdate={(event) => {
                    if (index !== activeIndex || advanceLockRef.current) return
                    const video = event.currentTarget
                    if (!Number.isFinite(video.duration) || video.duration <= 0) return
                    if (video.currentTime >= video.duration - 0.05) {
                      advance()
                    }
                  }}
                  onEnded={advance}
                >
                  <source src={clip.video} type="video/mp4" />
                </video>
              </motion.div>
            ))}
          </div>
        </DeviceFrame>
      </div>
    </div>
  )
}

function FlowSection() {
  return (
    <section id="flow" className="relative bg-background-secondary py-24">
      <div className="absolute inset-0 bg-auth-grid opacity-20" />
      <div className="absolute inset-0 bg-auth-noise opacity-20 mix-blend-soft-light" />
      <div className="relative mx-auto max-w-6xl px-6">
        <div className="grid gap-12 lg:grid-cols-[1.05fr,0.95fr]">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.22em] text-text-tertiary">
              The flow
            </p>
            <h2 className="mt-4 font-display text-[clamp(2rem,5vw,3.2rem)] font-semibold text-text-primary text-auth-soft">
              From chat to confirmed in minutes
            </h2>
            <p className="mt-4 max-w-xl text-lg text-text-secondary/90">
              PlanToMeet keeps every step lightweight so the group can decide fast without
              a wall of texts.
            </p>

            <div className="mt-8 space-y-4">
              {FLOW_STEPS.map((step, index) => (
                <div
                  key={step.title}
                  className="flex items-start gap-4 rounded-2xl border border-white/10 bg-white/5 p-4"
                >
                  <div className="mt-1 flex h-8 w-8 items-center justify-center rounded-full border border-white/10 bg-white/5 text-xs font-semibold text-text-tertiary">
                    0{index + 1}
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-text-primary">{step.title}</p>
                    <p className="mt-1 text-sm text-text-secondary">{step.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="relative">
            <div className="absolute -inset-6 rounded-3xl bg-gradient-to-br from-accent-blue/20 to-transparent blur-3xl" />
            <div className="relative rounded-3xl border border-white/10 bg-white/5 p-6 shadow-elevated backdrop-blur-xl">
              <FlowCarousel />
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

function DecisionSection() {
  const [activeNode, setActiveNode] = useState<string | null>(null)

  return (
    <section id="engine" className="relative bg-background py-24">
      <div className="pointer-events-none absolute inset-0 bg-auth-stars opacity-40" />
      <div className="pointer-events-none absolute inset-0 bg-auth-circuit opacity-45" />
      <div className="pointer-events-none absolute inset-0 bg-auth-circuit-dense opacity-55" />
      <EngineCircuitBackdrop />
      <CircuitBoardLayer className="opacity-35" idPrefix="engine-pcb" />
      <div className="pointer-events-none absolute inset-0 bg-auth-grid-fine opacity-25" />
      <div className="pointer-events-none absolute inset-0 bg-auth-noise opacity-25 mix-blend-soft-light" />
      <div className="pointer-events-none absolute inset-0 bg-auth-vignette opacity-80" />
      <div className="relative mx-auto max-w-6xl px-6 text-center">
        <p className="text-xs font-semibold uppercase tracking-[0.22em] text-text-tertiary">
          Decision engine
        </p>
        <h2 className="mt-4 font-display text-[clamp(2rem,5vw,3.2rem)] font-semibold text-text-primary text-auth-soft">
          Your group. Your data. Maximum clarity.
        </h2>
          <p className="mx-auto mt-4 max-w-2xl text-lg text-text-secondary/90">
            PlanToMeet pulls votes, chat, and calendar signals into one place so the best time
            is obvious for everyone.
          </p>

        <div
          className="relative mt-12 grid gap-4 md:block md:h-[420px]"
          onMouseLeave={() => setActiveNode(null)}
        >
          <svg
            className="pointer-events-none absolute inset-0 hidden md:block opacity-80"
            viewBox="0 0 1200 420"
            preserveAspectRatio="xMidYMid slice"
          >
            <defs>
              <linearGradient id="traceGlow" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor="rgba(126,166,255,0.35)" />
                <stop offset="100%" stopColor="rgba(127,231,255,0.2)" />
              </linearGradient>
              <filter id="traceBlur" x="-20%" y="-20%" width="140%" height="140%">
                <feGaussianBlur stdDeviation="2" result="blur" />
                <feMerge>
                  <feMergeNode in="blur" />
                  <feMergeNode in="SourceGraphic" />
                </feMerge>
              </filter>
            </defs>
            <g stroke="rgba(148, 163, 184, 0.18)" strokeWidth="1" fill="none">
              <path d="M60 90H260V150H360" />
              <path d="M1140 90H940V150H840" />
              <path d="M120 330H320V270H420" />
              <path d="M1080 330H880V270H780" />
              <path d="M220 40H220V120H320" />
              <path d="M980 40H980V120H880" />
              <path d="M300 380H300V300H420" />
              <path d="M900 380H900V300H780" />
            </g>
            <g filter="url(#traceBlur)">
              <path
                className="circuit-flow"
                d="M140 210H360V150H520"
                stroke="url(#traceGlow)"
                strokeWidth="1.5"
                fill="none"
              />
              <path
                className="circuit-flow-slow"
                d="M1060 210H840V150H680"
                stroke="url(#traceGlow)"
                strokeWidth="1.5"
                fill="none"
              />
              <path
                className="circuit-flow"
                d="M380 320H520V280H600"
                stroke="url(#traceGlow)"
                strokeWidth="1.5"
                fill="none"
              />
              <path
                className="circuit-flow-slow"
                d="M820 320H680V280H600"
                stroke="url(#traceGlow)"
                strokeWidth="1.5"
                fill="none"
              />
            </g>
            <g fill="rgba(148,163,184,0.25)">
              <rect x="520" y="140" width="80" height="50" rx="10" />
              <rect x="600" y="210" width="80" height="50" rx="10" />
              <rect x="520" y="230" width="80" height="50" rx="10" />
            </g>
            <g fill="rgba(127,231,255,0.5)" filter="url(#traceBlur)">
              <circle className="circuit-dot" cx="360" cy="150" r="3" />
              <circle className="circuit-dot" cx="840" cy="150" r="3" />
              <circle className="circuit-dot" cx="420" cy="270" r="3" />
              <circle className="circuit-dot" cx="780" cy="270" r="3" />
            </g>
          </svg>
          <svg
            className="pointer-events-none absolute inset-0 hidden md:block"
            viewBox="0 0 900 420"
            preserveAspectRatio="none"
          >
            <defs>
              <linearGradient id="circuitLine" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor="rgba(127,231,255,0.3)" />
                <stop offset="100%" stopColor="rgba(126,166,255,0.12)" />
              </linearGradient>
              <filter id="circuitGlow" x="-20%" y="-20%" width="140%" height="140%">
                <feGaussianBlur stdDeviation="2.5" result="blur" />
                <feMerge>
                  <feMergeNode in="blur" />
                  <feMergeNode in="SourceGraphic" />
                </feMerge>
              </filter>
            </defs>
            {[
              [450, 210, 110, 90],
              [450, 210, 790, 100],
              [450, 210, 160, 330],
              [450, 210, 760, 330],
              [450, 210, 450, 50],
              [450, 210, 450, 390],
            ].map((line, index) => (
              <g key={`line-${index}`} filter="url(#circuitGlow)">
                <line
                  x1={line[0]}
                  y1={line[1]}
                  x2={line[2]}
                  y2={line[3]}
                  className={index % 2 === 0 ? 'circuit-flow' : 'circuit-flow-slow'}
                  stroke="url(#circuitLine)"
                  strokeWidth="1.1"
                />
                <circle className="circuit-dot" cx={line[2]} cy={line[3]} r="2.5" fill="rgba(127,231,255,0.4)" />
              </g>
            ))}
          </svg>

          <motion.div
            className="mx-auto w-full max-w-sm rounded-3xl border border-white/12 bg-white/5 p-6 text-left shadow-[0_35px_120px_-70px_rgba(8,12,22,0.95)] backdrop-blur-2xl md:absolute md:left-1/2 md:top-1/2 md:-translate-x-1/2 md:-translate-y-1/2"
            style={{ transformStyle: 'preserve-3d', zIndex: 20 }}
            whileHover={{ y: -4, scale: 1.01 }}
            transition={{ type: 'spring', stiffness: 180, damping: 14 }}
          >
            <div className="pointer-events-none absolute -inset-10 rounded-[36px] bg-gradient-to-br from-accent-blue/18 via-accent-violet/12 to-transparent blur-3xl opacity-80" />
            <div className="pointer-events-none absolute inset-0 rounded-3xl bg-gradient-to-br from-white/10 via-white/4 to-transparent" />
            <div className="pointer-events-none absolute inset-0 rounded-3xl border border-white/16" />
            <div className="pointer-events-none absolute inset-[1px] rounded-[22px] border border-white/8" />
            <div className="pointer-events-none absolute inset-0 rounded-3xl edge-shine" />
            <div className="relative z-10">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold text-text-primary">PlanToMeet</p>
                  <p className="text-xs text-text-tertiary">Decision core</p>
                </div>
                <div className="relative h-10 w-10 rounded-2xl border border-white/20 bg-gradient-to-br from-accent-blue/35 to-accent-violet/35">
                  <span className="absolute inset-0 rounded-2xl bg-white/10" />
                </div>
              </div>
              <div className="mt-4 space-y-3 text-sm text-text-secondary">
                <div className="flex items-center justify-between rounded-xl border border-white/15 bg-white/8 px-3 py-2 shadow-[inset_0_1px_0_rgba(255,255,255,0.16)]">
                  <span>Responses</span>
                  <span className="text-accent-blue">9</span>
                </div>
                <div className="flex items-center justify-between rounded-xl border border-white/15 bg-white/8 px-3 py-2 shadow-[inset_0_1px_0_rgba(255,255,255,0.16)]">
                  <span>Best slot</span>
                  <span className="text-text-primary">Fri 7:30 PM</span>
                </div>
                <div className="flex items-center justify-between rounded-xl border border-white/15 bg-white/8 px-3 py-2 shadow-[inset_0_1px_0_rgba(255,255,255,0.16)]">
                  <span>Status</span>
                  <span className="text-accent-cyan">Ready</span>
                </div>
              </div>
            </div>
          </motion.div>

          <div className="grid gap-4 md:block">
            {DECISION_NODES.map((node, index) => (
              <motion.div
                key={node.label}
                className={`relative rounded-2xl border border-white/12 bg-white/6 px-4 py-3 text-sm text-text-secondary shadow-[0_12px_30px_-22px_rgba(8,12,22,0.85)] backdrop-blur-xl md:absolute ${node.position}`}
                style={{
                  transformStyle: 'preserve-3d',
                  zIndex: activeNode === node.label ? 30 : 10,
                }}
                animate={{
                  opacity: activeNode && activeNode !== node.label ? 0.7 : 1,
                }}
                whileHover={{
                  rotateX: 4,
                  rotateY: index % 2 === 0 ? 4 : -4,
                  scale: 1.01,
                }}
                onHoverStart={() => setActiveNode(node.label)}
                onHoverEnd={() => setActiveNode(null)}
                transition={{ type: 'spring', stiffness: 200, damping: 16 }}
              >
                <span className="pointer-events-none absolute inset-0 rounded-2xl bg-gradient-to-br from-white/10 via-transparent to-transparent" />
                <span className="pointer-events-none absolute -inset-3 rounded-2xl bg-gradient-to-br from-accent-cyan/12 to-transparent blur-2xl opacity-60" />
                <span className="pointer-events-none absolute inset-0 rounded-2xl edge-shine" />
                <span className="relative z-10" style={{ transform: 'translateZ(10px)' }}>
                  {node.label}
                </span>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}

function CTA() {
  return (
    <section className="relative bg-background-secondary py-24">
      <div className="absolute inset-0 bg-auth-radial opacity-70" />
      <div className="absolute inset-0 bg-auth-noise opacity-20 mix-blend-soft-light" />
      <div className="absolute inset-0 bg-auth-vignette opacity-80" />
      <motion.div
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, margin: '-100px' }}
        transition={{ duration: 0.6 }}
        className="relative mx-auto max-w-5xl overflow-hidden rounded-[32px] border border-white/10 bg-white/5 p-10 text-center text-white shadow-elevated backdrop-blur-xl md:p-16"
      >
        <div className="absolute -left-20 -top-20 h-60 w-60 rounded-full bg-accent-blue/20 blur-3xl" />
        <div className="absolute -bottom-24 -right-20 h-72 w-72 rounded-full bg-accent-violet/20 blur-3xl" />

        <div className="relative z-10">
          <p className="text-xs font-semibold uppercase tracking-[0.22em] text-text-tertiary">
            End the scheduling back and forth
          </p>
          <h2 className="mx-auto mt-4 max-w-3xl font-display text-[clamp(2rem,5vw,3.4rem)] font-semibold text-text-primary text-auth-soft">
            One poll. One decision. Zero chaos.
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-lg text-text-secondary/90">
            Start free on iPhone and send your first poll in under a minute.
          </p>

          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="group mt-8 inline-flex h-14 items-center gap-3 rounded-full bg-accent-blue px-8 text-base font-semibold text-[#05070C] shadow-soft transition hover:shadow-elevated"
          >
            <Apple className="h-5 w-5" />
            Download for iOS
            <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" />
          </a>
        </div>
      </motion.div>
    </section>
  )
}

function Footer() {
  return (
    <footer className="border-t border-white/10 bg-background px-6 py-12">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-6 text-sm text-text-tertiary sm:flex-row">
        <div className="flex items-center gap-3">
          <Image
            src="/icon-192.png"
            alt="PlanToMeet"
            width={28}
            height={28}
            className="rounded-lg border border-white/10 bg-[#0A0F1B]"
          />
          <span className="font-medium text-text-primary">PlanToMeet</span>
        </div>
        <span>(c) {new Date().getFullYear()} PlanToMeet. All rights reserved.</span>
        <div className="flex items-center gap-6">
          <Link href="/privacy" className="transition hover:text-text-primary">
            Privacy
          </Link>
          <Link href="/terms" className="transition hover:text-text-primary">
            Terms
          </Link>
          <a href="mailto:support@plantomeet.app" className="transition hover:text-text-primary">
            Contact
          </a>
        </div>
      </div>
    </footer>
  )
}

export default function LandingPage() {
  return (
    <main className="min-h-screen bg-background text-text-primary">
      <Navigation />
      <Hero />
      <FeatureRail />
      <FlowSection />
      <DecisionSection />
      <CTA />
      <Footer />
    </main>
  )
}
