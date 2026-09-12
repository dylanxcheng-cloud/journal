/**
 * native.js — bridge to the Capacitor shell. Every function is a no-op on the plain web,
 * so the site keeps working with no bundler and no native code.
 *
 * Native side (ios/App/App/SharedStorePlugin.swift) exposes:
 *   save({ json })          -> writes the snapshot into the App Group and reloads widgets
 *   readPending()           -> { toggles: [{ type: 'habit'|'event', id, key, at }] } from widget taps, then clears them
 * Local notifications go through @capacitor/local-notifications.
 */
import { buildSnapshot } from './snapshot.js';
import { todayKey } from './dates.js';

const cap = () => (typeof window !== 'undefined' && window.Capacitor) || null;
export const isNative = () => Boolean(cap() && cap().isNativePlatform && cap().isNativePlatform());

let sharedStore = null;
function plugin() {
  if (!isNative()) return null;
  if (!sharedStore) {
    try { sharedStore = cap().registerPlugin('SharedStore'); } catch { sharedStore = null; }
  }
  return sharedStore;
}
const localNotifications = () => (isNative() && cap().Plugins && cap().Plugins.LocalNotifications) || null;

let timer = null;
/** Debounced: called from the store subscription on every change. */
export function onStateChanged(state) {
  if (!isNative()) return;
  clearTimeout(timer);
  timer = setTimeout(() => sync(state), 400);
}

export async function sync(state) {
  if (!isNative()) return false;
  const snap = buildSnapshot(state);
  try {
    const p = plugin();
    if (p) await p.save({ json: JSON.stringify(snap) });
  } catch (err) { console.warn('SharedStore.save failed', err); }
  await scheduleNotifications(snap.notifications);
  return true;
}

/** Replace all pending OS notifications with the snapshot's list (iOS caps pending at 64). */
export async function scheduleNotifications(list) {
  const ln = localNotifications();
  if (!ln) return;
  try {
    let perm = await ln.checkPermissions();
    if (perm.display === 'prompt') perm = await ln.requestPermissions();
    if (perm.display !== 'granted') return;
    const pending = await ln.getPending();
    if (pending.notifications && pending.notifications.length) await ln.cancel(pending);
    if (!list.length) return;
    await ln.schedule({
      notifications: list.slice(0, 60).map((n, i) => ({
        id: i + 1, title: n.title, body: n.body, extra: { key: n.id },
        schedule: { at: new Date(n.at), allowWhileIdle: true },
      })),
    });
  } catch (err) { console.warn('LocalNotifications failed', err); }
}

/**
 * Apply taps made inside widgets while the app was closed. `applyToggle(type, id, key)` is
 * provided by the app so the store logic stays in one place.
 */
export async function applyPending(applyToggle) {
  const p = plugin();
  if (!p) return 0;
  try {
    const res = await p.readPending();
    const toggles = (res && res.toggles) || [];
    for (const t of toggles) applyToggle(t.type, t.id, t.key || todayKey());
    return toggles.length;
  } catch (err) { console.warn('SharedStore.readPending failed', err); return 0; }
}

/** Resume hook: re-apply pending toggles whenever the app comes back to the foreground. */
export function onResume(fn) {
  if (!isNative()) return;
  document.addEventListener('visibilitychange', () => document.visibilityState === 'visible' && fn());
  try { cap().Plugins.App && cap().Plugins.App.addListener('appStateChange', ({ isActive }) => isActive && fn()); } catch { /* optional */ }
}

/** Widgets open the app with daybook://<view>; route it to the matching tab. */
export function onDeepLink(fn) {
  if (!isNative()) return;
  try {
    cap().Plugins.App && cap().Plugins.App.addListener('appUrlOpen', ({ url }) => {
      const m = /^daybook:\/\/([a-z]+)/i.exec(url || '');
      if (m) fn(m[1].toLowerCase());
    });
  } catch { /* optional */ }
}
