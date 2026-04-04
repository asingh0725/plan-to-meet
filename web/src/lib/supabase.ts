import { createClient, RealtimeChannel } from '@supabase/supabase-js'

// MARK: - Custom REST Client

export interface SupabaseRequestOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'DELETE'
  params?: Record<string, string>
  body?: unknown
  headers?: Record<string, string>
}

export class SupabaseError extends Error {
  constructor(
    message: string,
    public statusCode: number,
    public details?: string
  ) {
    super(message)
    this.name = 'SupabaseError'
  }
}

function getSupabaseConfig() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new SupabaseError(
      'Missing Supabase configuration. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY.',
      0
    )
  }

  return {
    supabaseUrl,
    supabaseAnonKey,
    baseUrl: `${supabaseUrl}/rest/v1`,
  }
}

let realtimeClient: ReturnType<typeof createClient> | null = null

function getSupabaseClient() {
  if (realtimeClient) {
    return realtimeClient
  }

  const { supabaseUrl, supabaseAnonKey } = getSupabaseConfig()
  realtimeClient = createClient(supabaseUrl, supabaseAnonKey, {
    auth: { persistSession: false },
    realtime: { params: { eventsPerSecond: 10 } },
  })

  return realtimeClient
}

export async function supabaseRequest<T>(
  path: string,
  { method = 'GET', params, body, headers = {} }: SupabaseRequestOptions = {}
): Promise<T> {
  const { baseUrl, supabaseAnonKey } = getSupabaseConfig()
  const url = new URL(`${baseUrl}/${path}`)

  if (params) {
    for (const [key, value] of Object.entries(params)) {
      url.searchParams.set(key, value)
    }
  }

  try {
    const response = await fetch(url.toString(), {
      method,
      headers: {
        apikey: supabaseAnonKey!,
        Authorization: `Bearer ${supabaseAnonKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
        ...headers,
      },
      body: body ? JSON.stringify(body) : undefined,
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error(`Supabase ${method} ${path} failed:`, response.status, errorText)
      throw new SupabaseError(
        `Request failed with status ${response.status}`,
        response.status,
        errorText
      )
    }

    // Handle 204 No Content
    if (response.status === 204) {
      return null as T
    }

    const text = await response.text()
    if (!text) {
      return null as T
    }

    return JSON.parse(text) as T
  } catch (error) {
    if (error instanceof SupabaseError) {
      throw error
    }
    console.error(`Supabase request error for ${method} ${path}:`, error)
    throw new SupabaseError(
      error instanceof Error ? error.message : 'Unknown error',
      0
    )
  }
}

// MARK: - Realtime

/**
 * Creates a Supabase Realtime subscription that fires `onUpdate` whenever
 * a row in `responses` or `participants` changes for the given poll.
 *
 * Returns a cleanup function — call it when the component unmounts.
 */
export function createPollRealtimeSubscription(
  pollId: string,
  onUpdate: () => void
): () => void {
  let client: ReturnType<typeof createClient>

  try {
    client = getSupabaseClient()
  } catch (error) {
    console.warn('Supabase Realtime disabled:', error)
    return () => {}
  }

  const channel: RealtimeChannel = client
    .channel(`poll-${pollId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'responses',
        filter: `poll_id=eq.${pollId}`,
      },
      () => onUpdate()
    )
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'participants',
        filter: `poll_id=eq.${pollId}`,
      },
      () => onUpdate()
    )
    .subscribe()

  return () => {
    client.removeChannel(channel)
  }
}
