import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildSnapshot } from '../js/snapshot.js';
import { defaultState } from '../js/store.js';

function fixture() {
  const s = defaultState();
  s.habits.push({ id: 'h1', name: 'Read', color: '#33b679', days: [], createdAt: '2026-01-01T00:00:00.000Z' });
  s.habitLog['2026-09-12'] = { h1: true };
  s.events.push({
    id: 'e1', title: 'Standup', from: 'Work', date: '2026-09-07', time: '09:15', color: '#039be5',
    repeat: { type: 'weekly', weekdays: [1, 2, 3, 4, 5] },
    reminders: { push: { enabled: true, leadMinutes: 10 }, widget: { enabled: true }, wallpaper: { enabled: true } }, completed: {}, skipped: {},
  });
  s.events.push({
    id: 'e2', title: 'Rent', date: '2026-09-17', time: null, repeat: { type: 'monthly' },
    reminders: { push: { enabled: true, leadMinutes: 1440 }, widget: { enabled: false }, wallpaper: { enabled: true } }, completed: {}, skipped: {},
  });
  return s;
}

test('snapshot carries today, upcoming widget items and notifications', () => {
  const now = new Date(2026, 8, 12, 17, 0, 0); // Sat
  const snap = buildSnapshot(fixture(), now);
  assert.equal(snap.today.date, '2026-09-12');
  assert.deepEqual([snap.today.done, snap.today.total], [1, 1]);
  assert.equal(snap.today.habits[0].streak, 1);
  // Rent has widget disabled → not in upcoming; standup on Mon 14th is first
  assert.equal(snap.upcoming[0].title, 'Standup');
  assert.equal(snap.upcoming[0].key, '2026-09-14');
  assert.ok(snap.upcoming.every((u) => u.title !== 'Rent'));
  // Notifications: standup Mon 09:05 (10 min lead) comes before rent reminder Wed 16th 09:00 (1 day lead, all-day at 09:00)
  assert.equal(snap.notifications[0].at.slice(0, 16), '2026-09-14T09:05');
  const rent = snap.notifications.find((n) => n.title === 'Rent');
  assert.equal(rent.at.slice(0, 16), '2026-09-16T09:00');
  // Refresh moments include midnight
  assert.ok(snap.refreshAt.some((r) => r.startsWith('2026-09-13T00:00')));
});

test('already-fired reminders and completed occurrences are excluded', () => {
  const s = fixture();
  s.notified['e1|2026-09-14'] = Date.now();
  s.events[0].completed['2026-09-15'] = true;
  const snap = buildSnapshot(s, new Date(2026, 8, 12, 17));
  assert.ok(!snap.notifications.some((n) => n.id === 'e1|2026-09-14'));
  assert.ok(!snap.upcoming.some((u) => u.key === '2026-09-15'));
});
