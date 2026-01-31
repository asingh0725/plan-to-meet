const supabaseUrlEnv = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseAnonKeyEnv = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrlEnv || !supabaseAnonKeyEnv) {
  throw new Error('Missing Supabase configuration. Set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY.');
}

const supabaseUrl: string = supabaseUrlEnv;
const supabaseAnonKey: string = supabaseAnonKeyEnv;
const baseUrl = `${supabaseUrl}/rest/v1`;

interface SupabaseRequestOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'DELETE';
  params?: Record<string, string>;
  body?: unknown;
  headers?: Record<string, string>;
}

export async function supabaseRequest<T>(
  path: string,
  { method = 'GET', params, body, headers = {} }: SupabaseRequestOptions = {}
): Promise<T> {
  const url = new URL(`${baseUrl}/${path}`);
  if (params) {
    for (const [key, value] of Object.entries(params)) {
      url.searchParams.set(key, value);
    }
  }

  try {
    const response = await fetch(url.toString(), {
      method,
      headers: {
        apikey: supabaseAnonKey,
        Authorization: `Bearer ${supabaseAnonKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
        ...headers,
      },
      body: body ? JSON.stringify(body) : undefined,
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Supabase ${method} ${path} failed:`, response.status, errorText);
      throw new Error(errorText || `Supabase request failed with status ${response.status}`);
    }

    if (response.status === 204) {
      return null as T;
    }

    const text = await response.text();
    if (!text) {
      return null as T;
    }

    return JSON.parse(text) as T;
  } catch (error) {
    console.error(`Supabase request error for ${method} ${path}:`, error);
    throw error;
  }
}
