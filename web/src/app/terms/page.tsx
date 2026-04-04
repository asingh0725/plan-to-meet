import { Metadata } from 'next'
import Link from 'next/link'
import { ChevronLeft } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Terms of Service - PlanToMeet',
  description: 'Terms of Service for PlanToMeet - Read our terms and conditions.',
}

export default function TermsOfService() {
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
          <span className="text-xs font-semibold uppercase tracking-[0.2em] text-[#6d86b8]">Terms</span>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-6 py-12">
        <div className="rounded-[32px] border border-white/10 bg-white/[0.04] p-6 shadow-[0_30px_90px_-60px_rgba(6,10,24,1)] md:p-10">
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[#87a6e6]">PlanToMeet</p>
          <h1 className="mt-3 text-[clamp(2rem,4vw,3rem)] font-semibold tracking-tight text-white">Terms of Service</h1>
          <p className="mt-2 text-sm text-[#90a0c5]">Last updated: February 6, 2026</p>

          <div className="mt-8 space-y-8 text-sm leading-relaxed text-[#b9c5df]">
            <section>
              <h2 className="text-lg font-semibold text-white">Agreement to Terms</h2>
              <p className="mt-2">
                By accessing or using PlanToMeet (&quot;the Service&quot;), you agree to be bound by these Terms.
                If you do not agree, do not use the Service.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Description of Service</h2>
              <p className="mt-2">PlanToMeet helps groups find common meeting times. The Service lets you:</p>
              <ul className="mt-3 space-y-2">
                <li>Create scheduling polls with available time slots</li>
                <li>Share polls via iMessage or web links</li>
                <li>Vote on available times</li>
                <li>Finalize meeting times and add them to calendars</li>
              </ul>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">User Responsibilities</h2>
              <ul className="mt-3 space-y-2">
                <li>Provide accurate information when creating or responding to polls</li>
                <li>Use the Service only for lawful purposes</li>
                <li>Do not disrupt or interfere with the Service</li>
                <li>Do not harass, spam, or harm others</li>
                <li>Do not attempt unauthorized access to other user data</li>
              </ul>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Acceptable Use</h2>
              <p className="mt-2">You may not use the Service to:</p>
              <ul className="mt-3 space-y-2">
                <li>Violate applicable laws or regulations</li>
                <li>Infringe on the rights of others</li>
                <li>Distribute malware or harmful code</li>
                <li>Attempt to gain unauthorized access to our systems</li>
                <li>Collect user data without consent</li>
                <li>Create polls with offensive or inappropriate content</li>
              </ul>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Intellectual Property</h2>
              <p className="mt-2">
                The Service and its original content, features, and functionality are owned by PlanToMeet
                and protected by applicable intellectual property laws.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">User Content</h2>
              <p className="mt-2">
                You retain ownership of content you create. By using the Service, you grant us a license
                to store and display it to other poll participants.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Service Availability</h2>
              <p className="mt-2">
                We aim for high availability but do not guarantee uninterrupted access. The Service may
                be temporarily unavailable for maintenance or other factors beyond our control.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Disclaimer of Warranties</h2>
              <p className="mt-2">
                The Service is provided “as is” and “as available” without warranties of any kind.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Limitation of Liability</h2>
              <p className="mt-2">
                To the maximum extent permitted by law, PlanToMeet is not liable for any indirect,
                incidental, special, consequential, or punitive damages arising from your use of the Service.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Termination</h2>
              <p className="mt-2">
                We may terminate or suspend access to the Service without notice if conduct violates these
                Terms or is harmful to the Service or other users.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Changes to Terms</h2>
              <p className="mt-2">
                We may modify these Terms at any time. Continued use after changes constitutes acceptance.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Governing Law</h2>
              <p className="mt-2">
                These Terms are governed by the laws of the United States, without regard to conflict of law principles.
              </p>
            </section>

            <section>
              <h2 className="text-lg font-semibold text-white">Contact Us</h2>
              <p className="mt-2">
                If you have questions, contact us at{' '}
                <a href="mailto:legal@plantomeet.app" className="text-[#7dd3ff] hover:underline">
                  legal@plantomeet.app
                </a>.
              </p>
            </section>
          </div>
        </div>
      </main>
    </div>
  )
}
