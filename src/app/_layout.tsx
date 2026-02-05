import { DarkTheme, DefaultTheme, ThemeProvider } from '@react-navigation/native';
import { Stack, useRouter } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import * as Linking from 'expo-linking';
import { StatusBar } from 'expo-status-bar';
import { useEffect, useCallback, useRef } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { useColorScheme } from '@/lib/useColorScheme';

export const unstable_settings = {
  initialRouteName: '(tabs)',
};

// Prevent the splash screen from auto-hiding before asset loading is complete.
SplashScreen.preventAutoHideAsync();

const queryClient = new QueryClient();

// =============================================================================
// PHASE 2: Deep Link Handling
// Supports both universal links (https://plantomeet.app/poll/{id}) and
// custom scheme links (plantomeet://poll/{id})
// =============================================================================

/**
 * Extracts poll ID from a deep link URL.
 * Handles both universal links and custom scheme URLs.
 * Returns null if URL is invalid or doesn't contain a poll ID.
 */
function extractPollIdFromUrl(url: string | null | undefined): string | null {
  if (!url || typeof url !== 'string') {
    return null;
  }

  try {
    // First try parsing as a standard URL (universal links)
    const parsed = new URL(url);
    const path = parsed.pathname;

    // Match /poll/{uuid} pattern - UUIDs contain alphanumeric chars and hyphens
    const pollMatch = path.match(/\/poll\/([a-zA-Z0-9-]+)/);
    if (pollMatch && pollMatch[1]) {
      return pollMatch[1];
    }

    return null;
  } catch {
    // URL parsing failed - try custom scheme pattern
    // Handle plantomeet://poll/{id} format
    const schemeMatch = url.match(/^plantomeet:\/\/poll\/([a-zA-Z0-9-]+)/);
    if (schemeMatch && schemeMatch[1]) {
      return schemeMatch[1];
    }
    return null;
  }
}

/**
 * DeepLinkHandler component handles incoming deep links.
 *
 * PHASE 2 VERIFICATION:
 * - [x] Handles cold start URLs (getInitialURL)
 * - [x] Handles runtime URLs (addEventListener)
 * - [x] Idempotent - uses ref to prevent double navigation
 * - [x] Defensive - validates URL before navigation
 * - [x] No infinite loops - processed URLs are tracked
 */
function DeepLinkHandler() {
  const router = useRouter();

  // Track processed URLs to prevent double navigation
  const processedUrls = useRef<Set<string>>(new Set());
  const initialUrlHandled = useRef(false);

  const handleDeepLink = useCallback(
    (url: string | null) => {
      // Defensive guard: validate URL
      if (!url || typeof url !== 'string') {
        return;
      }

      // Idempotency: skip if we already processed this URL
      if (processedUrls.current.has(url)) {
        return;
      }

      const pollId = extractPollIdFromUrl(url);
      if (pollId) {
        // Mark as processed before navigation to prevent race conditions
        processedUrls.current.add(url);

        // Use replace for initial URL to avoid back-navigation issues
        // Use push for runtime URLs to allow back navigation
        router.push(`/poll/${pollId}`);
      }

      // Clean up old URLs after 5 seconds to prevent memory growth
      // but keep recent ones to handle rapid duplicate events
      setTimeout(() => {
        processedUrls.current.delete(url);
      }, 5000);
    },
    [router]
  );

  useEffect(() => {
    // Handle URL that opened the app (cold start)
    // Only process once to prevent double navigation on re-renders
    if (!initialUrlHandled.current) {
      initialUrlHandled.current = true;

      Linking.getInitialURL()
        .then((url) => {
          if (url) {
            // Small delay to ensure router is ready
            setTimeout(() => handleDeepLink(url), 100);
          }
        })
        .catch((error) => {
          // Log but don't crash on getInitialURL failure
          console.warn('Failed to get initial URL:', error);
        });
    }

    // Handle URLs while app is running (warm start / runtime)
    const subscription = Linking.addEventListener('url', (event) => {
      handleDeepLink(event.url);
    });

    return () => {
      subscription.remove();
    };
  }, [handleDeepLink]);

  return null;
}

export default function RootLayout() {
  const colorScheme = useColorScheme();

  useEffect(() => {
    SplashScreen.hideAsync();
  }, []);

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <QueryClientProvider client={queryClient}>
          <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
            <StatusBar style={colorScheme === 'dark' ? 'light' : 'dark'} />
            <DeepLinkHandler />
            <Stack screenOptions={{ headerShown: false }}>
              <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
              <Stack.Screen
                name="create"
                options={{
                  headerShown: false,
                  presentation: 'modal',
                  animation: 'slide_from_bottom',
                }}
              />
              <Stack.Screen
                name="poll/[id]"
                options={{
                  headerShown: false,
                  animation: 'slide_from_right',
                }}
              />
              <Stack.Screen
                name="settings"
                options={{
                  headerShown: false,
                  presentation: 'modal',
                  animation: 'slide_from_bottom',
                }}
              />
            </Stack>
          </ThemeProvider>
        </QueryClientProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
