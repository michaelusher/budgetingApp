# Budget Buddy

A personal budgeting app built with Flutter. Track expenses, set category
budgets, plan savings goals, and see where your money goes each month —
everything is stored locally on your device.

## Features

- **Dashboard** — month-scoped "left to spend" balance, quick stats (daily
  average, projection to month end), budget alerts when a category nears its
  limit, and a per-category spending breakdown.
- **Smart quick add** — type naturally ("coffee 4.50 yesterday", "netflix
  15.99 monthly") and the amount, category, date, and repeat are parsed
  automatically. Runs entirely on-device: free, offline, and private.
- **Receipt scanning (optional)** — photograph a receipt and the merchant,
  total, date, and category are read for you via Google's free Gemini API
  tier. Two modes:
  - *Personal/dev*: bring your own free key from aistudio.google.com,
    stored only on the device.
  - *Store builds*: deploy the free Cloudflare Worker in
    [proxy/receipt_scan_worker.js](proxy/receipt_scan_worker.js) (it holds
    the key server-side, so users can never extract it) and build with
    `--dart-define=SCAN_PROXY_URL=https://your-worker.workers.dev`.
- **Transactions** — searchable history grouped by day with daily totals,
  category and month filters, swipe to delete, tap to edit.
- **Recurring transactions** — mark an expense as daily/weekly/monthly/yearly
  and future occurrences are posted automatically.
- **Budgets** — per-category monthly limits with progress and over-budget
  indicators, plus an expected-budget forecast view.
- **Savings goals** — targets with deposit history and progress tracking.
- **Charts** — visual breakdown of spending by category.
- **Personalization** — light/dark/system theme and a choice of currencies.
- **Data management** — export transactions as CSV, back up and restore all
  data as JSON, or erase everything.

## Getting started

```sh
flutter pub get
flutter run
```

Run the tests with:

```sh
flutter test
```

## Project layout

- `lib/state/` — `AppState`: app-wide state, persistence (SharedPreferences),
  recurring-transaction posting, import/export.
- `lib/models/` — plain data models (transactions, budgets, goals).
- `lib/screens/` — one file per page; `main_shell.dart` holds navigation.
- `lib/widgets/` — shared widgets and formatting helpers.
- `lib/theme/` — design tokens and light/dark themes.
- `lib/constants/` — categories, currencies, goal icons.

## History

This project started in my fall 2022 Mobile Application Development course,
where I built a financial advisory app with Dart and Flutter in stages. The
original stage 3 submission is kept in this repo as `mainStage3.dart`, with a
demo video in `stage3.mov`.
