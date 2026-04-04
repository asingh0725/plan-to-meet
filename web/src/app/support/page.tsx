import { Metadata } from 'next'
import Link from 'next/link'
import { ChevronLeft, LifeBuoy, Mail, Shield, FileText } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Support - PlanToMeet',
  description: 'Support and contact information for PlanToMeet.',
}

const supportItems = [
  {
    icon: LifeBuoy,
    title: 'General Support',
    body: 'Questions, bug reports, and feature requests.',
    href: 'mailto:support@plantomeet.app',
    label: 'support@plantomeet.app',
  },
  {
    icon: Shield,
    title: 'Privacy Requests',
    body: 'Data deletion requests and privacy questions.',
    href: 'mailto:privacy@plantomeet.app',
    label: 'privacy@plantomeet.app',
  },
  {
    icon: FileText,
    title: 'Legal',
    body: 'Terms, policy, and legal contact.',
    href: 'mailto:legal@plantomeet.app',
    label: 'legal@plantomeet.app',
  },
]

export default function SupportPage() {
  return (
    <div className="min-h-screen bg-[#040815] text-white">
      <header className="sticky top-0 z-40 border-b border-white/10 bg-[#091021]/70 backdrop-blur-xl">
        <div className="mx-auto flex max-w-4xl items-center justify-between px-6 py-4">
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-sm font-medium text-[#a8b6d4] transition hover:text-white"
          >
            <ChevronLeft className="h-4 w-4" />
            Back
          </Link>
          <span className="text-xs font-semibold uppercase tracking-[0.2em] text-[#6d86b8]">Support</span>
        </div>
      </header>

      <main className="mx-auto max-w-4xl px-6 py-12">
        <div className="rounded-[32px] border border-white/10 bg-white/[0.04] p-6 shadow-[0_30px_90px_-60px_rgba(6,10,24,1)] md:p-10">
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#87a6e6]">PlanToMeet</p>
          <h1 className="mt-3 text-[clamp(2rem,4vw,3rem)] font-semibold tracking-tight text-white">Support</h1>
          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-[#b9c5df]">
            Use this page as the App Store Connect support contact for PlanToMeet. Include your
            device model, iOS version, and a poll link when relevant so issues can be reproduced
            quickly.
          </p>

          <div className="mt-8 grid gap-4 md:grid-cols-3">
            {supportItems.map(({ icon: Icon, title, body, href, label }) => (
              <a
                key={title}
                href={href}
                className="rounded-[24px] border border-white/10 bg-white/[0.03] p-5 transition hover:border-white/20 hover:bg-white/[0.05]"
              >
                <Icon className="h-5 w-5 text-[#7dd3ff]" />
                <h2 className="mt-4 text-base font-semibold text-white">{title}</h2>
                <p className="mt-2 text-sm leading-relaxed text-[#a8b6d4]">{body}</p>
                <div className="mt-4 inline-flex items-center gap-2 text-sm font-medium text-[#7dd3ff]">
                  <Mail className="h-4 w-4" />
                  {label}
                </div>
              </a>
            ))}
          </div>

          <div className="mt-8 rounded-[24px] border border-white/10 bg-[#0a1224] p-5">
            <h2 className="text-base font-semibold text-white">Privacy and Data Requests</h2>
            <p className="mt-2 text-sm leading-relaxed text-[#b9c5df]">
              PlanToMeet does not require accounts. If you want poll data deleted, email{' '}
              <a href="mailto:privacy@plantomeet.app" className="text-[#7dd3ff] hover:underline">
                privacy@plantomeet.app
              </a>{' '}
              and include any relevant poll links or details that help identify the request.
            </p>
          </div>

          <div className="mt-8 flex flex-wrap gap-4 text-sm text-[#90a0c5]">
            <Link href="/privacy" className="text-[#7dd3ff] hover:underline">
              Privacy Policy
            </Link>
            <Link href="/terms" className="text-[#7dd3ff] hover:underline">
              Terms of Service
            </Link>
            <a href="https://plantomeet.app" className="text-[#7dd3ff] hover:underline">
              plantomeet.app
            </a>
          </div>
        </div>
      </main>
    </div>
  )
}
