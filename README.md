# Daybook

A small journaling web app: daily habits, a journal, and the things people ask you to do, with three
ways to be reminded. Plain HTML, CSS and ES modules; no build step, no backend, no accounts. Everything
stays on the device.

**Run it locally:** `python3 -m http.server 8000` in this folder, then open <http://localhost:8000/>.

**Deploy:** it is a static site. Point GitHub Pages (Settings → Pages → branch `main`, folder `/`) or
Netlify at the repository root. Notifications and the installable app need HTTPS, which both provide.

## The idea

- **Habits** are things you do on repeat. Pick the weekdays, tick them off, keep a streak.
- **Journal** is one plain note per day, with a mood.
- **Events** are things someone asked you to do. Once, or repeating daily / weekly / monthly / yearly.
  Tick off each occurrence, or skip just one.
- **Every event can remind you three ways**, any mix:
  1. **Notification** before it happens (calendar-style lead time), plus an optional daily habit nudge.
  2. **Wallpaper**: a lock-screen image of today's habits and upcoming events, sized for your phone.
  3. **Widget**: a live one-glance page you add to the home screen.

Design: Google Calendar's schedule view (date circles, colored chips, blue accent, "+" button) for
events, and a Notes-style paper card and checklists for the journal and habits.

## Files

```
  index.html, widget.html, manifest.webmanifest, sw.js, css/app.css
  js/store.js      one JSON document in localStorage; export/import
  js/dates.js      date helpers      js/recur.js     recurrence engine
  js/habits.js     streaks           js/reminders.js notification scheduling
  js/ics.js        add-to-calendar   js/wallpaper.js canvas renderer
  js/app.js        UI                js/widget.js    widget page
  tests/           node --test tests/*.test.mjs
  tools/make-icons.mjs
```

## What the web version can't do (and the workaround)

- Notifications fire only while Daybook is open (a tab or the installed app). For alerts when it's
  closed, press **.ics** on an event to drop it into the phone's calendar with the same alert.
- The wallpaper is an image you set yourself; web pages can't change a phone's wallpaper.
- The widget is a page, not a system widget.

## iOS app with home-screen and lock-screen widgets

The web app is the source of truth. Capacitor wraps it into a native app, and a small WidgetKit
extension draws a snapshot the web layer writes into a shared App Group. Swift never re-implements
recurrence or streaks; `js/snapshot.js` precomputes everything the widgets and OS notifications need.

```
js/snapshot.js                 today's habits, upcoming events, refresh times, notification list
js/native.js                   bridge: no-op on the web, talks to Capacitor in the app
ios/App/App/SharedStorePlugin.swift   save snapshot → App Group, reload widgets; read widget taps
ios/App/App/MainViewController.swift  registers the plugin
ios/Shared/                    SharedStore.swift + Snapshot.swift (add to BOTH targets)
ios/DaybookWidget/             the widget extension: bundle, timeline provider, views, intents
```

What you get: widgets in small / medium / large (iPhone and iPad) and extra large (iPad),
lock-screen circular / rectangular / inline widgets showing habit progress and the next event,
tap-to-tick habits and events from the widget on iOS 17+, deep links into the right tab, and
notifications scheduled by iOS that fire with the app closed.

### One-time setup on a Mac

Needs Xcode 15+, CocoaPods (`brew install cocoapods`) and Node 20+.

1. `npm install && npm run ios:sync` (copies the site into `www/` and syncs it into `ios/App/App/public`).
2. `cd ios/App && pod install`, then `npm run ios:open` (opens `App.xcworkspace`).
3. **App target**: drag `ios/App/App/SharedStorePlugin.swift`, `MainViewController.swift` and both
   files in `ios/Shared/` into the App group in Xcode (tick "App" as target). Under Signing &
   Capabilities pick your team, add **App Groups** and enable `group.com.daybook.app`
   (`App.entitlements` is already wired in). Add **Push Notifications** is not needed; local
   notifications work without it.
4. **Widget target**: File → New → Target → Widget Extension, name `DaybookWidget`, untick
   "Include Configuration App Intent". Delete the Swift files Xcode generated, then drag in every
   file from `ios/DaybookWidget/` and both files from `ios/Shared/` (tick "DaybookWidget" as
   target). Add the same App Group to this target (`DaybookWidget.entitlements` is provided).
5. Change `com.daybook.app` to your own bundle id in `capacitor.config.json`, both entitlements
   files, `ios/Shared/SharedStore.swift` (`appGroup`) and the Xcode signing pane. The App Group id
   must be `group.` + your bundle id on both targets.
6. Run on a device or simulator, open Daybook once so it writes the first snapshot, then add the
   widget from the home screen or lock screen gallery.

Day to day: edit the web files, `npm run ios:sync`, build in Xcode. A free Apple ID installs on your
own devices for 7 days; the paid developer program is needed for TestFlight and the App Store.

### How the pieces talk

- On every change the web store calls `native.onStateChanged`, which builds the snapshot, hands it
  to `SharedStore.save`, and replaces the pending local notifications (iOS allows 64; the nearest
  60 are scheduled and topped up on each launch).
- The widget's `Provider` reads the snapshot and builds one timeline entry per refresh moment
  (midnight, each event time), so it updates without the app running.
- A tap in a widget runs an App Intent that queues a toggle in the App Group and flips the stored
  snapshot immediately. When the app next opens or resumes, `native.applyPending` replays the queue
  through the normal store update.
- Android later: the same snapshot feeds a Jetpack Glance widget and `WallpaperManager` can set the
  generated wallpaper automatically.

## Other reminder ideas

- Add-to-calendar (built) and a snooze / "still not done" re-alert.
- A morning summary notification: today's habits and asks in one line.
- Share-sheet capture: share a text or email into Daybook to create an event.
- Natural-language entry: "every other Tuesday at 7".
- Weekly review prompt in the journal with the week's streaks and completed asks.
