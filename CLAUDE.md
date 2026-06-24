# CLAUDE.md — Health Tracker

Instructions for future Claude sessions in this project. Keep it concise and instructional.

## What this is
A native **macOS SwiftUI** habit tracker, built as a **Swift Package executable** (no
`.xcodeproj` — don't create one). Plain source files, easy to edit and rebuild.

## Build / run
- Compile: `swift build`
- Dev run (opens the window): `swift run HealthTracker`
- Distributable app: `./build.sh` → assembles `Health Tracker.app` (Info.plist, ad-hoc
  codesign) and generates the icon via `Tools/makeicon.swift` → `AppIcon.icns` if missing.
- **No test target.** A clean `swift build` is the de-facto check. `swift test` reports
  "no tests found" — that's expected.
- Toolchain: Swift 6.3 available, but the manifest is `swift-tools-version:5.9`
  (**Swift 5 language mode**). Keep it there — avoids Swift 6 strict-concurrency churn.

## Core rule: Markdown is the source of truth
There is **no database**. Each habit is a folder under the vault (`HabitData/`):
- `habit.md` — YAML frontmatter (config, parsed by **Yams**) + Markdown body (`details`).
- `log.md` — a Markdown table, one row per logged session/day. Columns are **field ids**
  (date first). The app reads these back on launch; hand-edits are respected (⌘R reloads).

All persistence funnels through `Store/VaultStore.swift`. UI mutations go through
`ViewModels/AppState.swift`, which writes to disk **immediately** on every change.

## The flexible habit model (add habits without code)
A `Habit` = `fields` + `targets` + `cadence` + `goal`. One model expresses all habits.
- Field kinds: `toggle`, `counter` (integer), `choice`, `note` (free text).
- Target kinds: `dailyAllToggles`, `weeklyCount`, `weeklyChoiceCounts`, `counterTrendUp`.
- Goals: `completion`, `higherIsBetter`, `lowerIsBetter`.
- Defaults live in `Seed/SeedHabits.swift` (seeded only when the vault is empty).

## Conventions & gotchas
- **Counters are integers.** For decimal values (e.g. running distance in km) use a `note`
  field, not `counter` — that's why Running's `distance` is a note.
- **log.md cells must not contain a raw `|`** (breaks the table). The writer escapes it;
  keep notes pipe-free when hand-writing.
- **Week starts Monday** — see `DayMath` in `Models/LogEntry.swift`. Use its helpers.
- When you change a seed's schema, also update the matching `HabitData/<Habit>/habit.md`
  in the live vault if the change must apply to existing data (seeds only affect fresh vaults).
- Heatmap (`Views/HeatmapView.swift`) and detail stats are **shared across all habits**;
  behaviour varies only by `goal`. Don't special-case one habit.
- **Today grid uses SwiftUI `Grid`, not `LazyVGrid`.** `LazyVGrid` + `.frame(maxHeight: .infinity)`
  (the equal-height trick) overlaps rows. `Grid` does equal-height rows / equal-width columns
  correctly. Don't switch it back.
- **Never make a root `GeometryReader` the split-view detail.** It ignores safe-area insets
  and draws content under the sidebar. To measure width, use a *background* `GeometryReader`
  + `PreferenceKey` (see `TodayView`).
- **Habit display order** persists in `<vault>/.order` (one habit id per line). The sidebar
  `.onMove` and the Today grid both read `AppState.habits`, ordered by `VaultStore` via
  `readOrder()`/`saveOrder()`. New/deleted habits update `.order` only if it already exists.
- `WeeklyProgressView.swift` is **unused** (progress bars are inlined in `HabitDetailView`) —
  safe to delete.
- **Environment limitation:** `rm` and `git rm` are blocked here. To delete a file, ask the
  user to remove it (or empty it via Edit); expect manual cleanup.

## Vault location
Resolved in `VaultStore.defaultVaultURL()`: env `HEALTH_TRACKER_VAULT` →
UserDefaults `vaultPath` → default `~/Documents/Health Tracker/HabitData`. Use the env
var for throwaway test vaults, or to point at an iCloud Drive folder.

## Remote
GitHub: **tarkabit/health-tracker** (public, MIT © Tarkabit), `origin` → `main`.

## Do not commit
`HabitData/` (personal health data, incl. `.order`), `.build/`, `*.app/`, `.DS_Store`,
`AppIcon.iconset/` — all gitignored.
