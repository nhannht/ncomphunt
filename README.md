<p align="center">
  <img src="./assets/compyhunt-icon-iOS-Default-1024x1024@1x.png" alt="nCompHunt icon" width="128" height="128">
</p>

<h1 align="center">nCompHunt</h1>

<p align="center">
  <a href="https://apps.apple.com/app/id6791654003"><img src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-mac-app-store/black/en-us?releaseDate=1753315200" alt="Download on the Mac App Store" height="44"></a>
</p>

<p align="center">
  <a href="https://github.com/nhannht/ncomphunt/releases"><img src="https://img.shields.io/github/v/release/nhannht/ncomphunt?label=release&color=3574F0" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white" alt="macOS 26 or later">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/Developer%20ID-notarized-1C3D7A" alt="Developer ID notarized">
  <img src="https://img.shields.io/badge/license-MIT-555555" alt="MIT license">
</p>

<p align="center">
  <a href="https://youtu.be/S0OubPVMVRQ"><img src="./assets/demo-search.gif" alt="Typing the sentence 'vietnam ctf end this month' and having nCompHunt read it on device and turn it into a filter"></a>
</p>

<p align="center">
  <a href="https://youtu.be/S0OubPVMVRQ">Watch the full demo with sound (1 min 47 sec)</a>
</p>

Native macOS app that finds and indexes competitions - competitive programming,
AI challenges, CTFs, hackathons, and design contests - in Vietnam and globally,
and lists them with sort and group controls, category and region filters, a menu
bar extra, native notifications for new finds, and an optional sync into a
dedicated Apple Calendar that keeps every deadline up to date.

Built in Swift 6 / SwiftUI with SwiftData persistence. There is no account to
create and no setup: the app talks directly to the public sources below and
keeps its index in local storage on your Mac.

## How it works

Every refresh fans out to all enabled sources in parallel, deduplicates by
normalized URL, and lands everything in one list. Filter it, put a deadline on
the calendar, and get a notification when something new arrives.

![Animated schematic: sources feeding one list, a filter click, a calendar entry, and a notification](./assets/schematics/schematic-hero.gif)

## Install

- **Mac App Store** (recommended):
  [nCompHunt on the Mac App Store](https://apps.apple.com/app/id6791654003) -
  free, and updates arrive automatically
- **Homebrew**: `brew install --cask nhannht/tap/ncomphunt`
- **Direct download**: grab the latest notarized `.dmg` from
  [Releases](https://github.com/nhannht/ncomphunt/releases)
- **Build from source**: see [Build](#build) below

Every build is sandboxed and behaves identically. The only difference is first
launch: the Homebrew and direct-download builds are signed with an Apple
Developer ID and notarized by Apple, so macOS asks you once to confirm opening
an app downloaded from the internet - click **Open**. You will not see an
"unidentified developer" warning. The Mac App Store build skips that prompt.

## Sources

Every source has an enable checkbox in Settings; a failing or unconfigured
source is skipped, never kills a refresh. The keyless sources below need zero
configuration and fill every category out of the box.

- CTFtime API v1 - the canonical worldwide CTF calendar
- Devpost - global hackathons with prizes, themes, and deadlines
- Codeforces API - upcoming competitive-programming rounds (keyless)
- MLContests - open AI/ML competitions across Kaggle, Zindi, Codabench, Hugging
  Face, DrivenData, and AIcrowd (keyless)
- ybox.vn - Vietnamese design, scholarship, and general-interest competitions
  (Vietnam's CP/CTF/AI contests arrive through the aggregators above, tagged by
  region detection)
- Contest Watchers - creative and design competition directory (RSS)
- clist.by API v4 - aggregator broadening competitive programming with AtCoder,
  LeetCode, CodeChef, HackerRank and hundreds more (requires a free API key)
- Brave Search + Google Programmable Search - lead discovery over a fixed
  bilingual query catalog, at most once per day to stay inside free API quotas
  (both need free keys; leads with no dates age out after 14 days unseen)

## Configuration (optional API keys)

Enter optional API keys under **Settings > API Keys**. Keys are stored securely
in the macOS Keychain, and each keyed source turns on as soon as its key is
present. Missing keys simply disable that source.

The keys are:

- `CLIST_USERNAME` + `CLIST_API_KEY` - clist.by
- `BRAVE_API_KEY` - Brave Search
- `GOOGLE_CSE_KEY` + `GOOGLE_CSE_CX` - Google Programmable Search

If you used an older build backed by a `~/.claude/secrets.yml` file, the
**Import from secrets.yml** button migrates those keys into the Keychain. It
opens a file picker, which is what grants the sandboxed app access to that file,
so the migration works in every build.

The optional YouTrack action files one Task issue per competition into a `COMP`
project. Enter the instance base URL and a bearer token under
**Settings > YouTrack**; both are stored in the Keychain alongside the API keys.
The `~/.claude.json` discovery under `mcpServers.youtrack` is a fallback for the
`CompHuntKit` library outside the app (tests and CLI use) - the shipped app is
sandboxed and cannot reach that file.

## Menu bar

The menu bar extra keeps the next deadlines one click away all day, with live
countdowns on what is closing soon. Skim it and get back to work - no window
needed.

![Animated schematic: the status item opens a dropdown of upcoming deadlines with countdowns](./assets/schematics/schematic-menubar.gif)

## Filter, sort, group

Category and region filters, sort by deadline or first seen, and grouping that
shows the week at a glance - all from the toolbar of a native SwiftUI window.

![Animated schematic: one click sorts the list, the next clusters it under group headers](./assets/schematics/schematic-filter.gif)

## Calendar sync

Optional sync mirrors every tracked deadline into a dedicated "nCompHunt"
Apple Calendar and keeps it reconciled: when an organizer moves a date, the
event moves with it.

![Animated schematic: a sync toggle sends each deadline into a month view, then a moved deadline relocates its event](./assets/schematics/schematic-calendar.gif)

## Notifications

Background refreshes keep hunting while you work. When new competitions are
found, a native macOS notification tells you - notifications are optional and
requested only when you turn them on.

![Animated schematic: a background refresh drops new rows into the list and a notification slides in](./assets/schematics/schematic-notifications.gif)

## Actions

Right-click any row (or use the detail header menu): open page, share via the
system sheet (Notes, Messages, Mail, AirDrop), copy link, add to Calendar as an
.ics import, and file into YouTrack (if configured).

![Animated schematic: a right-click opens the row context menu and Copy Link confirms](./assets/schematics/schematic-actions.gif)

## Widget

An **Upcoming Contests** widget for the desktop and Notification Centre, in
small and medium sizes, showing the next competitions with a live countdown. It
reads a snapshot the app writes into a shared App Group container.

![Animated schematic: the desktop widget counts a deadline down and rotates in the next contest](./assets/schematics/schematic-widget.gif)

## Layout

- `Sources/CompHuntKit/` - core library: models, source plugins, refresh engine,
  YouTrack sink (SwiftPM)
- `Tests/CompHuntKitTests/` - fixture-based parser, classifier, and dedupe tests
- `App/` - SwiftUI app (main window + menu bar extra + widget), project generated
  with XcodeGen from `App/project.yml`

## Build

- Tests: `swift test`
- App: `cd App && xcodegen generate && xcodebuild -project CompHunt.xcodeproj -scheme CompHunt build`

## Requirements

- macOS 26+; building from source needs Xcode 26+ and XcodeGen

## License

MIT - see [LICENSE](LICENSE).
