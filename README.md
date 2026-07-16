# Expense Tracker

A local-first Flutter expense tracker with credit-card repayment accounting and bill splitting.
Material 3, Riverpod, Hive. No network, no accounts, no telemetry — everything stays on the device.

> **Full documentation:** open [`docs/index.html`](docs/index.html) in a browser.
> It covers setup, architecture, the data model, every source file, and — most importantly —
> the **business rules** that govern which month an expense counts against.

## Quick start

```bash
flutter pub get

# Generate the Hive type adapters (*.g.dart). Required — the app won't compile without them.
dart run build_runner build --delete-conflicting-outputs

flutter run
```

Requires Flutter ≥ 3.16 (Dart ≥ 3.4), JDK 17, and an Android 13+ (API 33) device or emulator.

```bash
flutter test      # 34 tests — run from the repo root
flutter analyze   # clean
```

## The two rules worth knowing up front

Most of this app is a list of numbers. These two rules are why it isn't trivial, and why a
screen that sums `expense.amount` by `expense.date` will disagree with the dashboard:

**1. A credit-card expense counts in the month you pay the card**, not the month you swiped it.
An unpaid card expense counts against no month at all — it's a liability, shown as "Card due".
Swipe on 20 May, pay on 3 June → it counts against **June's** salary.

**2. Only your share of a split counts.** When you front a bill, each person who repays you is
subtracted from what that expense cost you. If they repay in a later month, the month you
originally paid is *corrected*, and the correction flows forward into every later month's
carry-over.

Both rules live in `expense_repository.dart` (`getAccountingDate`, `getCountedAmount`) and
`balance_repository.dart` (`rebuildCarryOverChain`). Use those methods rather than
re-deriving the arithmetic in a widget.

## Layout

```
lib/
├── core/          theme (design tokens, money colours), constants, date/currency utils
├── data/          models (Hive), repositories (the accounting), services (backup, migration)
└── presentation/  providers (Riverpod), screens, widgets
```

## Before publishing

Two hard blockers, both covered in [`PUBLISH_CHECKLIST.md`](PUBLISH_CHECKLIST.md):

- No keystore, so release builds fall back to the **debug key**. The Gradle side
  is already wired: drop in `android/key.properties` (Step 3-4) and it signs for
  real. The fallback is quiet — `apksigner verify --print-certs` on the APK is
  the way to know what signed it.
- The package is still `com.example.expense_tracker`, which Play will not accept.

## Known limitations

- A "month" is always a calendar month — there's no payday/cycle setting.
- The web target can't compile (`dart:io` in the export service).
- Importing a backup is **destructive** — it makes your data match the file rather than merging.

See the [Known issues](docs/index.html#issues) section of the docs for the full list.
