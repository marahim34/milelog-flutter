# Handoff: MileLog — Mileage Tracker

## Overview
MileLog is a professional-grade mileage tracking Android app for business owners, employees, and freelancers who need an audit-ready log of vehicle trips for tax/reimbursement purposes. The product's headline value is "set it and forget it" tracking via Bluetooth and Geofencing automation, with a Finnish/European tax context (default rate €0.55/km).

This bundle contains a high-fidelity HTML prototype covering the core 5-tab navigation, primary screens, and key sub-flows.

## About the Design Files
The files in `prototype/` are **design references** built in HTML/React (in-browser Babel). They show intended look, layout, color, type, motion, and interaction — they are **not production code**.

Recreate these designs in the target Android codebase using its established patterns and libraries (Jetpack Compose with Material 3 is recommended given the visual direction). All measurements, colors, and copy in this README are authoritative.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, iconography, and interactions are locked. Recreate pixel-perfectly.

---

## Navigation Structure

5-tab bottom navigation with an elevated center FAB:

| Position | Tab | Icon | Purpose |
|---|---|---|---|
| 1 | Drive | Navigation arrow | Active trip / start tracking |
| 2 | Trips | Route dots | Dashboard + trip history |
| 3 | **FAB** (center, elevated 26dp) | Play | **Tap** = open Start Trip sheet · **Swipe up** = radial menu (Start Trip / Odometer / Log Mileage) |
| 4 | Reports | Bar chart | Monthly + all-time analytics |
| 5 | Settings | Gear | Configuration |

FAB visual: 62×62dp, 20dp corner radius, accent fill, 6dp ring matching surface bg, drop shadow `0 12px 28px accent@45%`.

---

## Screens

### 1. Active Navigation (Drive tab while trip in progress)
- **Top half:** Map placeholder with traveled route (solid) + remaining route (dashed), start pin, current vehicle indicator (rotating triangle).
- **Top status:** GPS chip (success), Recording chip (accent, pulsing dot).
- **Speed badge:** bottom-left of map, current km/h, large tabular number.
- **Bottom sheet:** Big km counter (58sp tabular), elapsed time MM:SS, route summary (from → to), red full-width "End trip" button (tapping opens Trip Detail editor).

### 2. Trips / Dashboard
- Greeting + user name, GPS status chip.
- **Hero card:** "This month · APR 2026", 34 trips, huge km figure (54sp tabular), reimbursable amount in accent color, 30-day sparkline (accent line + gradient fill, today marked), legend with business/personal split bar.
- **Auto-tracker card:** title + status chip (Active/Standby), connected vehicle row with icon, plate, BT status; toggle switch; mini route preview map.
- **Start Trip CTA** full-width (only when not in active trip view).
- **Recent trips list:** route-glyph (start circle, dashed line, end circle), from/to, time/duration/company, distance + business/personal label.

### 3. Reports
- Range toggle: **This month / All time**.
- **Hero stat card:** total km (56sp), 3-stat grid (Business / Personal / Trips), reimbursable callout @ 0.55 €/km in accent tint.
- **Daily activity heatmap** (monthly only): 6×7 grid, accent opacity 0.2 → 1.0 by intensity, "less ↔ more" legend.
- **By-client donut chart:** 110×110, 14dp stroke, segment colors: accent / accent-2 / personal / fg-ghost. Legend with percentages.
- **Export grid (2×):** PDF (Tax-ready), CSV (Spreadsheet) — card buttons with icon, label, sub.

### 4. Settings
- Large title with version stamp `MILELOG / v2.4.1`.
- **Permissions alert** (warning-bordered card) when any permission needs review.
- Sections (each a Card with internal `1px var(--border)` dividers between rows, 64dp row height):
  - **Auto-tracking**: Bluetooth auto-start, Geofencing, Continuous GPS (each: icon, title, subtitle, switch).
  - **Cloud services**: account row + sync chip; two action buttons (Sync now / Restore).
  - **Management**: Vehicles, Workplaces, Odometer log (chevron, opens sheet/screen).
  - **Preferences**: Mileage rate, Appearance, Language.
  - **Permissions**: status chips (Granted / Review).
  - **About**: profile, Sign out (danger).
- Footer: monospace build stamp.

### 5. Sub-flows (bottom sheets)
- **Start Trip sheet** (FAB tap): Business/Personal segmented, vehicle picker, big "Start trip" button.
- **Trip Detail editor** (after end-trip): Type segmented, odometer Start → End fields, computed distance card, Company, Notes, Save/Cancel.
- **Odometer Log screen**: hero current reading; entries list with horizontal bar showing delta km, date, total reading.
- **Rate editor**: big € display, preset chips (0.45 / 0.50 / 0.55 / 0.60), hint text.
- **Theme picker**: Follow system / Light / Dark.
- **Language picker**: English / Suomi.
- **Vehicle list** & **Workplace list** sheets.

---

## Design Tokens

### Color — Dark theme (default for driving context)
Use these as CSS custom properties or Compose theme values. Three palettes ship; **Rose is primary**, Lime and Cyan are alternates the product can offer.

#### Palette: Rose (primary)
| Token | Hex / oklch |
|---|---|
| `--bg` | `#140910` |
| `--bg-elev` | `#1F1018` |
| `--bg-elev-2` | `#2A1722` |
| `--bg-inset` | `#0B0508` |
| `--border` | `#2E1A25` |
| `--border-strong` | `#3F2433` |
| `--fg` | `#F6EEF3` |
| `--fg-dim` | `#B8A0AE` |
| `--fg-dimmer` | `#816A78` |
| `--fg-ghost` | `#4A3742` |
| `--accent` | `oklch(0.72 0.19 5)` |
| `--accent-2` | `oklch(0.78 0.15 45)` |
| `--accent-tint` | `oklch(0.72 0.19 5 / 0.14)` |
| `--accent-ink` | `#15080E` |
| `--success` | `oklch(0.78 0.16 150)` |
| `--danger` | `oklch(0.68 0.22 25)` |
| `--warning` | `oklch(0.82 0.16 85)` |
| `--biz` | `oklch(0.72 0.19 5)` |
| `--personal` | `oklch(0.78 0.15 250)` |

(See `prototype/styles.css` for Lime, Cyan, and Light-mode variants.)

### Light Mode (mandatory — daylight visibility)
The app **must** ship Light + Dark + Follow System. Default to "Follow system" so Android handles auto-switching. Light values are in `styles.css` under `:root[data-theme='light']`.

### Typography
- **Primary:** Space Grotesk (Google Fonts) — 400 / 500 / 600 / 700.
- **Mono / micro-labels:** JetBrains Mono — 400 / 500.
- Always use **tabular numerics** for stats (km, €, time): `font-feature-settings: 'tnum'`.

| Use | Font / Size / Weight |
|---|---|
| Screen title (large) | Space Grotesk 28–32sp / 600 / -0.025em |
| Hero number (km, time) | Space Grotesk 46–58sp / 600 / -0.03em / tnum |
| Body | Space Grotesk 14–16sp / 500 |
| Section label | JetBrains Mono 10–11sp / 500 / 0.14em uppercase, color `--fg-dimmer` |
| Micro-label / metadata | JetBrains Mono 10–11sp / 0.04–0.1em |

### Spacing & shape
- 4dp base. Common: 4 / 8 / 10 / 14 / 16 / 18 / 20 / 24.
- Card radius: **18dp**. Inner row padding: 14dp v / 18dp h.
- Button radius: 12–14dp. FAB radius: 20dp.
- 64dp setting row min-height. 44dp minimum touch target.

### Iconography
Custom 24dp icon set — see `prototype/components/icons.jsx` for all SVG paths. Required icons: Bluetooth, Location, Cloud, Odometer, Vehicle, Money, Profile, Theme, Trip, Play, Stop, Chevron, Back, Plus, Check, Signal, Clock, Settings, Chart, Home, Search, Download, Briefcase, Navigation, Edit, Doc.

Re-implement as VectorDrawable XML or Compose `ImageVector`. **Do not ship emoji.**

### Status chips
Outlined pill, 1dp border in tone color, 5×10dp padding, 6dp radius, optional pulsing 6×6dp dot. Tones: accent / success / danger / warning / dim.

---

## Interactions

- **FAB swipe-up:** pointer events; threshold 40px reveals radial menu (3 actions arranged at -140°, -90°, -40° around FAB, 85px radius). Tap outside dismisses.
- **Sheets:** slide-up from bottom, 250ms `cubic-bezier(.2,.8,.2,1)`, scrim `rgba(0,0,0,.5)`, drag handle 36×4dp.
- **Switches:** 48×28dp, 200ms transition on background + thumb position/size (14→20dp).
- **Active trip:** km counter increments live, speed jitters realistically. Persist trip state to local storage so a process kill doesn't lose the trip.

## State

Per-screen state implied:
- Active trip: `{ tripId, startTimestamp, vehicleId, type, currentKm, currentSpeed, gpsPoints[] }`.
- Settings: `{ btAutoStart, geofencing, continuousGps, mileageRate, theme, palette, language }`.
- Reports range: `'month' | 'all'`.

## Required behaviors (engineering notes)
- Background location permission flow (Android 10+ requires "Allow all the time" with rationale).
- Bluetooth nearby-devices permission (Android 12+).
- Geofence registration per workplace (radius in meters, persisted).
- Cloud sync status surfaced as the last-synced timestamp.
- Export PDF (tax authority format) and CSV.
- i18n: ship EN + FI minimum (string tables in `prototype/components/ui.jsx` → `STRINGS`). Number formatting: Finnish uses `,` as decimal separator and `€` after the value.

## Files in this bundle
```
prototype/
  index.html          # entry — open in browser to view all 3 screens side-by-side
  styles.css          # all design tokens (Dark + Light × Rose/Lime/Cyan)
  app.jsx             # app shell + tweaks panel wiring
  frames/             # Android device chrome (status bar, nav bar)
  components/
    icons.jsx         # all 24dp icons
    ui.jsx            # primitives + i18n strings + mock data
    navbar.jsx        # 5-tab nav + FAB + radial menu
    dashboard.jsx     # Trips/Dashboard screen
    reports.jsx       # Reports v2
    settings.jsx      # Settings + sub-sheets
    flows.jsx         # Active Navigation, Trip Detail, Odometer Log, Start Trip sheet
```

To preview: open `prototype/index.html` in a browser. Use the Tweaks toggle in the top toolbar of the host environment (or just edit `TWEAKS` in `index.html`) to switch theme, palette, and language.
