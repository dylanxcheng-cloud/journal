/**
 * snapshot.js — everything a native widget or notification scheduler needs,
 * precomputed in JS so Swift/Kotlin never re-implement recurrence or streaks.
 *
 * Shape (all dates ISO-8601 local wall-clock with offset, keys YYYY-MM-DD):
 * {
 *   version, generatedAt, today: { date, done, total, habits: [{ id, name, color, done, streak }] },
 *   upcoming: [{ eventId, key, title, from, time, color, at, allDay }],
 *   refreshAt: [iso...],            // moments the widget should re-render
 *   notifications: [{ id, title, body, at }]   // for OS-scheduled local notifications
 * }
 */
import { addDays, todayKey, atTime, formatTime } from './dates.js';
import { habitsForDay, isDone, streak } from './habits.js';
import { occurrencesBetween } from './recur.js';
import { fireTime, reminderKey } from './reminders.js';

export const SNAPSHOT_VERSION = 1;

function iso(d) {
  const p = (n) => String(n).padStart(2, '0');
  const off = -d.getTimezoneOffset();
  const sign = off >= 0 ? '+' : '-';
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}${sign}${p(Math.floor(Math.abs(off) / 60))}:${p(Math.abs(off) % 60)}`;
}

export function buildSnapshot(state, now = new Date(), { days = 14, maxUpcoming = 20, maxNotifications = 60 } = {}) {
  const today = todayKey(now);
  const habits = habitsForDay(state.habits, today).map((h) => ({
    id: h.id, name: h.name, color: h.color || '#33b679',
    done: isDone(state.habitLog, h.id, today), streak: streak(h, state.habitLog, today),
  }));

  const to = addDays(today, days);
  const upcoming = [];
  const notifications = [];
  for (const ev of state.events) {
    const rem = ev.reminders || {};
    for (const key of occurrencesBetween(ev, today, to)) {
      if (ev.completed && ev.completed[key]) continue;
      const at = atTime(key, ev.time || state.settings.allDayReminderTime || '09:00');
      if (ev.time && at < now && key === today) continue; // already passed today
      if (rem.widget && rem.widget.enabled) {
        upcoming.push({ eventId: ev.id, key, title: ev.title, from: ev.from || '', time: ev.time || null, allDay: !ev.time, color: ev.color || '#039be5', at: iso(at) });
      }
      if (rem.push && rem.push.enabled && !state.notified[reminderKey(ev.id, key)]) {
        const fire = fireTime(ev, key, state.settings);
        if (fire > now) {
          notifications.push({
            id: reminderKey(ev.id, key), title: ev.title,
            body: `${key === today ? 'Today' : key}${ev.time ? ' at ' + formatTime(ev.time) : ''}${ev.from ? ' · for ' + ev.from : ''}`,
            at: iso(fire),
          });
        }
      }
    }
  }
  upcoming.sort((a, b) => a.at.localeCompare(b.at));
  notifications.sort((a, b) => a.at.localeCompare(b.at));

  const hr = state.settings.habitReminder;
  if (hr && hr.enabled && habits.length) {
    for (let i = 0; i < 7 && notifications.length < maxNotifications; i++) {
      const k = addDays(today, i);
      const at = atTime(k, hr.time || '08:00');
      if (at <= now || state.notified[`habits|${k}`]) continue;
      notifications.push({ id: `habits|${k}`, title: 'Daily habits', body: 'Time to check in on your habits.', at: iso(at) });
    }
    notifications.sort((a, b) => a.at.localeCompare(b.at));
  }

  // Widget refresh moments: midnight, and each upcoming event time within 48h.
  const midnight = atTime(addDays(today, 1), '00:00');
  const refresh = new Set([iso(midnight)]);
  for (const u of upcoming) if (new Date(u.at) - now < 48 * 3600000) refresh.add(u.at);

  return {
    version: SNAPSHOT_VERSION,
    generatedAt: iso(now),
    today: { date: today, done: habits.filter((h) => h.done).length, total: habits.length, habits },
    upcoming: upcoming.slice(0, maxUpcoming),
    refreshAt: [...refresh].sort(),
    notifications: notifications.slice(0, maxNotifications),
  };
}
