import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SecureStore from 'expo-secure-store';
import { v4 as uuidv4 } from 'uuid';

const SESSION_ID_KEY = 'plantomeet.sessionId';
const DISPLAY_NAME_KEY = 'plantomeet.displayName';

async function getStorageItem(key: string): Promise<string | null> {
  try {
    if (await SecureStore.isAvailableAsync()) {
      return await SecureStore.getItemAsync(key);
    }
  } catch {
    // fall back to AsyncStorage
  }
  return await AsyncStorage.getItem(key);
}

async function setStorageItem(key: string, value: string): Promise<void> {
  try {
    if (await SecureStore.isAvailableAsync()) {
      await SecureStore.setItemAsync(key, value);
      return;
    }
  } catch {
    // fall back to AsyncStorage
  }
  await AsyncStorage.setItem(key, value);
}

export async function getOrCreateSessionId(): Promise<string> {
  const existing = await getStorageItem(SESSION_ID_KEY);
  if (existing) return existing;

  const newId = uuidv4();
  await setStorageItem(SESSION_ID_KEY, newId);
  return newId;
}

export async function getStoredDisplayName(): Promise<string> {
  const name = await getStorageItem(DISPLAY_NAME_KEY);
  return name ?? '';
}

export async function setStoredDisplayName(name: string): Promise<void> {
  await setStorageItem(DISPLAY_NAME_KEY, name);
}
