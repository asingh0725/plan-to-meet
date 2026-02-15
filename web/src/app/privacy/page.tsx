import { Metadata } from 'next'
import Link from 'next/link'
import { ChevronLeft } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Privacy Policy - PlanToMeet',
  description: 'Privacy Policy for PlanToMeet - Learn how we handle your data.',
}

export default function PrivacyPolicy() {
  return (
    <div className="min-h-screen bg-[#040815] text-white">
      <header className="sticky top-0 z-40 border-b border-white/10 bg-[#091021]/70 backdrop-blur-xl">
        <div className="mx-auto flex max-w-3xl items-center justify-between px-6 py-4">
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-sm font-medium text-[#a8b6d4] transition hover:text-white"
          >
            <ChevronLeft className="h-4 w-4" />
            Back
          </Link>
          <span className="text-xs font-semibold uppercase tracking-[0.2em] text-[#6d86b8]">Privacy</span>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-6 py-12">
        <div className="rounded-[32px] border border-white/10 bg-white/[0.04] p-6 shadow-[0_30px_90px_-60px_rgba(6,10,24,1)] md:p-10">
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#87a6e6]">PlanToMeet</p>
          <h1 className="mt-3 text-[clamp(2rem,4vw,3rem)] font-semibold tracking-tight text-white">Privacy Policy</h1>
          <p className="mt-2 text-sm text-[#90a0c5]">Last updated: February 15, 2026</p>

          <div className="mt-8 space-y-8 text-sm leading-relaxed text-[#b9c5df]">
            <section>
              <h2 className="text-lg font-semibold text-white">Overview</h2>
              <p className="mt-2">
                PlanToMeet ("we", "our", or "us") is committed to protecting your privacy. This
                Privacy Policy explains how we collect, use, and safeguard your information when you
                use our mobile application and website.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Information We Collect</h2>
              <p className="mt-2">We collect minimal information necessary to provide our scheduling service:</p>
              <ul className="mt-3 space-y-2">
                <li><span className="text-white font-medium">Display Name:</span> The name you choose to show when voting on polls.</li>
                <li><span className="text-white font-medium">Poll Data:</span> Poll titles, time slots, and availability responses you create or join.</li>
                <li><span className="text-white font-medium">Session Identifier:</span> A random identifier stored on your device to track your responses.</li>
              </ul>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">What We Don’t Collect</h2>
              <ul className="mt-3 space-y-2">
                <li>No account registration or email required</li>
                <li>No phone number or contacts collected</li>
                <li>No calendar access or storage</li>
                <li>No location tracking</li>
                <li>No advertising or tracking cookies</li>
              </ul>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">How We Use Your Information</h2>
              <ul className="mt-3 space-y-2">
                <li>Display your name and availability to other poll participants</li>
                <li>Calculate the best meeting times based on responses</li>
                <li>Generate calendar events when a time is finalized</li>
              </ul>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Data Storage</h2>
              <p className="mt-2">
                Poll data is stored securely using Supabase. Data is encrypted in transit and at rest.
                We retain finalized polls until 14 days after the finalized meeting date, and open polls
                until 7 days after the end of the date range. After retention, we delete responses, time
                slots, participants, and availability blocks, and keep a minimal non-user-facing metadata
                stub for audit and analytics.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Data Sharing</h2>
              <p className="mt-2">
                We do not sell, trade, or rent your personal information to third parties. Poll data is
                visible only to participants with the poll link.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Your Rights</h2>
              <ul className="mt-3 space-y-2">
                <li>Access your poll data</li>
                <li>Request deletion of your data</li>
                <li>Change your display name at any time</li>
              </ul>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Children’s Privacy</h2>
              <p className="mt-2">
                Our service is not directed to children under 13. We do not knowingly collect personal
                information from children under 13.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Changes to This Policy</h2>
              <p className="mt-2">
                We may update this Privacy Policy from time to time. We will post the updated policy
                on this page and update the “Last updated” date.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Contact Us</h2>
              <p className="mt-2">
                If you have questions, contact us at{' '}
                <a href="mailto:privacy@plantomeet.app" className="text-[#7dd3ff] hover:underline">
                  privacy@plantomeet.app
                </a>.
              </p>
            </section>
          </div>
        </div>
      </main>
    </div>
  )
}
