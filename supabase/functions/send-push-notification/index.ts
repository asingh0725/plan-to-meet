/**
 * Supabase Edge Function: send-push-notification
 *
 * Triggered via Supabase Database Webhooks:
 *   1. INSERT on `responses`  → notify poll creator that someone responded
 *   2. UPDATE on `polls` WHERE status = 'finalized' → notify all participants
 *
 * Required secrets (set with `supabase secrets set`):
 *   APNS_KEY_P8       — contents of the .p8 file (APNs Auth Key)
 *   APNS_KEY_ID       — 10-char Key ID from Apple Developer portal
 *   APNS_TEAM_ID      — 10-char Team ID from Apple Developer portal
 *   APNS_BUNDLE_ID    — com.aviraj.plantomeet
 *   SUPABASE_URL      — your project URL
 *   SUPABASE_SERVICE_ROLE_KEY — service role key (bypasses RLS)
 *
 * Deploy:
 *   supabase functions deploy send-push-notification
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const APNS_HOST = 'https://api.push.apple.com'
const APNS_KEY_P8 = Deno.env.get('APNS_KEY_P8') ?? ''
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID') ?? ''
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID') ?? ''
const APNS_BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID') ?? 'com.aviraj.plantomeet'
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

// ---------------------------------------------------------------------------
// APNs JWT helpers
// ---------------------------------------------------------------------------

/** Sign a JWT for APNs using the ES256 p8 key. */
async function makeApnsJwt(): Promise<string> {
  const header = { alg: 'ES256', kid: APNS_KEY_ID }
  const payload = { iss: APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) }

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const headerB64 = encode(header)
  const payloadB64 = encode(payload)
  const signingInput = `${headerB64}.${payloadB64}`

  // Import the p8 key (PKCS8 PEM → CryptoKey)
  const pemBody = APNS_KEY_P8
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0))
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  )

  const sigBytes = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    new TextEncoder().encode(signingInput),
  )

  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sigBytes)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  return `${signingInput}.${sigB64}`
}

/** Send a single APNs push to one device token. */
async function sendApns(
  deviceToken: string,
  title: string,
  body: string,
  jwt: string,
): Promise<void> {
  const url = `${APNS_HOST}/3/device/${deviceToken}`
  const payload = JSON.stringify({
    aps: { alert: { title, body }, sound: 'default', badge: 1 },
  })

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      authorization: `bearer ${jwt}`,
      'apns-topic': APNS_BUNDLE_ID,
      'apns-push-type': 'alert',
      'content-type': 'application/json',
    },
    body: payload,
  })

  if (!res.ok) {
    const err = await res.text()
    console.error(`APNs error for token ${deviceToken.slice(0, 8)}…: ${res.status} ${err}`)
  }
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  try {
    const event = await req.json()
    const table: string = event.table
    const record = event.record
    const oldRecord = event.old_record

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    const jwt = await makeApnsJwt()

    if (table === 'responses') {
      // New response inserted — notify the poll creator
      const pollId: string = record.poll_id

      const { data: poll } = await supabase
        .from('polls')
        .select('creator_session_id, title')
        .eq('id', pollId)
        .single()

      if (!poll?.creator_session_id) return new Response('ok')

      // Don't notify the creator if they responded to their own poll
      if (record.session_id === poll.creator_session_id) return new Response('ok')

      const { data: tokens } = await supabase
        .from('push_tokens')
        .select('token')
        .eq('session_id', poll.creator_session_id)

      for (const row of tokens ?? []) {
        await sendApns(row.token, poll.title, 'Someone responded to your poll', jwt)
      }
    } else if (table === 'polls' && record.status === 'finalized' && oldRecord?.status !== 'finalized') {
      // Poll just finalized — notify all participants (except the finalizer)
      const pollId: string = record.id

      const { data: participants } = await supabase
        .from('participants')
        .select('session_id')
        .eq('poll_id', pollId)
        .neq('session_id', record.creator_session_id)

      if (!participants?.length) return new Response('ok')

      const sessionIds = participants.map((p: { session_id: string }) => p.session_id)

      const { data: tokens } = await supabase
        .from('push_tokens')
        .select('token')
        .in('session_id', sessionIds)

      for (const row of tokens ?? []) {
        await sendApns(row.token, record.title, 'A meeting time has been chosen!', jwt)
      }
    }

    return new Response('ok', { status: 200 })
  } catch (err) {
    console.error('send-push-notification error:', err)
    return new Response('error', { status: 500 })
  }
})
