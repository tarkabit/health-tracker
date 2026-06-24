# Health Tracker

A fast, clean **native macOS** habit tracker (SwiftUI). Every habit lives in its own
folder, and each day's record is written to a human-readable Markdown file — the Markdown
*is* the source of truth, so your data is portable, iCloud-synced, and editable by hand.

## Run it

```bash
# Quick dev run
swift run HealthTracker

# Build a double-clickable app
./build.sh
open "Health Tracker.app"

# Install
cp -R "Health Tracker.app" /Applications/
```

Open `Package.swift` in Xcode to develop with previews/debugger. `build.sh` also
generates the app icon (`Tools/makeicon.swift` → `AppIcon.icns`) if it's missing.

## In the app

- **Today** — every habit as a card with a one-gesture inline logger (checklist chips,
  easy/fast/long taps, +/− counters), live weekly progress, and a completion ring.
- **Habit detail** — an interactive **activity heatmap** (month/weekday labels, "today"
  outline; tap any day to log or edit it), goal-aware headline stats, weekly progress
  bars, and a full editable history.
- **New / Edit habit** — define fields, targets, cadence, icon and color from the UI.
- **Reorder** — drag habits in the sidebar to set their order (e.g. daily ones on top);
  the order is saved and the Today grid follows it.

## Where your data lives

By default your vault is `~/Documents/Health Tracker/HabitData/`, one folder per habit:

```
HabitData/
  Running/        habit.md   log.md
  Food/           habit.md   log.md
  Meditation/     ...
  Weight Lifting/
  Pull-ups/
  Headache & Tablets/
```

- **`habit.md`** — YAML frontmatter (the habit's config) + a Markdown description.
- **`log.md`** — a Markdown table, one row per logged session/day.

**Choose a different location** (resolution order): the `HEALTH_TRACKER_VAULT`
environment variable → the path saved from a previous launch → the default above.
To sync via iCloud Drive, set `HEALTH_TRACKER_VAULT` to a folder under
`~/Library/Mobile Documents/com~apple~CloudDocs/…`.

## The six seeded habits

| Habit | How it's tracked |
|-------|------------------|
| Running | Tap easy / fast / long — target 2 / 2 / 1 per week |
| Food | Checklist: clean breakfast/lunch/dinner, protein, water, no deviation |
| Meditation | Toggle a session — 3 per week |
| Weight Lifting | Tap push / pull / lower — 1 each per week |
| Pull-ups | Counter, "higher is better", every other day |
| Headache & Tablets | Log occurrence + tablet count, "fewer is better" |

## How it's built

One flexible model expresses every habit, so new habits need no code:

- **Fields** you log: `toggle`, `counter`, `choice`, `note`
- **Targets** evaluated weekly (week starts Monday): `dailyAllToggles`,
  `weeklyCount`, `weeklyChoiceCounts`, `counterTrendUp`
- **Cadence**: daily / every other day / weekly
- **Goal**: complete the target / higher is better / fewer is better

### Layout

```
Sources/HealthTracker/
  HealthTrackerApp.swift     App entry
  Models/                    Habit, LogEntry, WeekProgress
  Store/                     VaultStore, HabitFile (Yams), LogFile (table)
  ViewModels/AppState.swift  Loads on launch, writes every edit to disk
  Seed/SeedHabits.swift      The six defaults
  Views/                     Today, HabitCard, Detail, Heatmap, editors…
```

The only dependency is [Yams](https://github.com/jpsim/Yams) for YAML frontmatter.

## License

[MIT](LICENSE).
