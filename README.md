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

### Building the apps

Every push builds both apps in GitHub Actions (see the **iOS** and **Android** workflows):

- **Android:** the workflow uploads `Daybook-android-debug-apk`. Download it from the run, copy it
  to a phone and open it (allow installs from unknown sources). No accounts needed.
- **iOS:** the workflow compiles the app **and the widget extension** on a macOS runner and uploads
  a simulator build. Installing on a real iPhone needs Apple code signing, which means a Mac with
  Xcode once, or signing secrets in CI (Apple Developer Program, US$99/year, for TestFlight and the
  App Store; a free Apple ID can install on your own devices for 7 days from Xcode).

On a Mac (Xcode 15+, CocoaPods, Node 20+):

```
npm install
npm run ios:sync        # copies the site, syncs Capacitor, then runs tools/ios-configure.rb
cd ios/App && pod install && cd ../..
npm run ios:open        # opens the workspace; pick your team under Signing & Capabilities, then Run
```

`tools/ios-configure.rb` does the Xcode wiring for you: adds the plugin and shared files to the App
target, creates the `DaybookWidget` extension target with its sources, Info.plist and entitlements,
links WidgetKit and SwiftUI, embeds the extension, and sets iOS 17 as the minimum. It is idempotent.
The only manual steps are choosing your signing team and, if you change the bundle id, updating
`com.daybook.app` in `capacitor.config.json`, both `.entitlements` files and
`ios/Shared/SharedStore.swift` (the App Group must be `group.` + bundle id).

Android: `npm run android:apk` builds `android/app/build/outputs/apk/debug/app-debug.apk` locally
(needs Java 21 and the Android SDK, or just use the workflow).

### How the pieces talk

- On every change the web store calls `native.onStateChanged`, which builds the snapshot, hands it
  to `SharedStore.save`, and replaces the pending local notifications (iOS allows 64; the nearest
  60 are scheduled and topped up on each launch).
- The widget's `Provider` reads the snapshot and builds one timeline entry per refresh moment
  (midnight, each event time), so it updates without the app running.
- A tap in a widget runs an App Intent that queues a toggle in the App Group and flips the stored
  snapshot immediately. When the app next opens or resumes, `native.applyPending` replays the queue
  through the normal store update.
- Android: the app builds and runs today; a Jetpack Glance widget fed by the same snapshot, and
  automatic wallpaper via `WallpaperManager`, are the next native pieces.

## Other reminder ideas

- Add-to-calendar (built) and a snooze / "still not done" re-alert.
- A morning summary notification: today's habits and asks in one line.
- Share-sheet capture: share a text or email into Daybook to create an event.
- Natural-language entry: "every other Tuesday at 7".
- Weekly review prompt in the journal with the week's streaks and completed asks.
