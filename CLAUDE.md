# CLAUDE.md

nCompHunt - native macOS + iOS (Swift/SwiftUI) competition indexer.
Display/product name is nCompHunt (bundle id com.nhannht.ncomphunt on BOTH
platforms - same App Store record, universal purchase; DMG slug ncomphunt); the
internal code names - target, scheme, xcodeproj, CompHuntKit module - remain
CompHunt. iOS targets are CompHuntiOS + CompHuntWidgetiOS (iPhone + iPad,
deployment target iOS 26). Finds and lists
competitive programming contests, AI competitions, CTFs, hackathons, and design
contests, Vietnam-first and global. Sibling of `../job-tracker/recon` (the Python
job-recon engine) and follows its proven patterns: source plugins, normalized-URL
dedupe, a failing source never kills a run.

## Design file (Sketch, source of truth)

`~/Documents/sketch/ncompthunt.sketch` (outside the repo) is the design source
of truth. Attached library: Apple macOS 27 UI Kit (id
`E5937708-71B4-4D44-BB64-4B0E2CF20DE0`) - reuse its symbols/styles for any UI
chrome; the kit ships no widget component, so the Widget Kit card is hand-built.
One page, "CompHunt UI":

- UI mocks, canonical (kit-based, updated to 1.0.0): `Main Window Kit`,
  `Settings Kit` (API Keys + Calendar sections, editable YouTrack),
  `Menu Bar Kit`, `Actions Menu Kit`, `Widget Kit`
- Legacy hand-rolled mocks (pre-kit, historical): `Main Window`, `Settings`,
  `Menu Bar Extra`, `Actions Menu`
- `appstore screenshot` - user staging frame: raw 1.0.0 captures + MacBook bezel
- `github showcase` - README hero composition
- `AS 1 Hero` .. `AS 5 Widget` - the five 2880x1800 App Store artboards
  (gradient #D825FC>#1C3D7A>#3574F0, white SF Pro Display caption, floating
  panel); exported 1x to `showcase/appstore/as*.png` for ASC upload

Structural changes to the document (pages/artboards/symbols) must update this
map in the same turn.

## Build and test (CLI only, never JetBrains build)

- Library tests: `swift test`
- App build: `cd App && xcodegen generate && xcodebuild -project CompHunt.xcodeproj -scheme CompHunt build 2>&1 | tail -50`
- iOS app build: same xcodegen, then `xcodebuild -project CompHunt.xcodeproj -scheme CompHuntiOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -50`
- `App/CompHunt.xcodeproj` is generated from `App/project.yml` (XcodeGen) and
  gitignored - edit `project.yml`, never the xcodeproj.
- Release: `scripts/release.sh {build|notarize|appstore}`. `notarize` builds the
  Developer ID DMG (needs a stored `notarytool` keychain profile). `appstore`
  archives with Apple Distribution signing and uploads to App Store Connect when
  the ASC API key env vars (`ASC_KEY_P8` / `ASC_KEY_ID` / `ASC_ISSUER_ID`) are
  set - a key lives at `~/.appstoreconnect/private/` - otherwise it exports a
  `.pkg` for manual Transporter upload. Bump `CURRENT_PROJECT_VERSION` in
  `project.yml` for every new App Store build.

## Layout

- `Sources/CompHuntKit/Models/` - `CompetitionDTO` (Sendable struct sources
  return), `Competition` (SwiftData `@Model`, `#Unique` on `key`), `Category`
  (cp/ctf/ai/hackathon/design/other), `Region` (vietnam/global)
- `Sources/CompHuntKit/Sources/` - one file per source implementing
  `CompetitionSource` (`fetch() async throws -> [CompetitionDTO]`): CTFtime,
  Devpost, clist.by, Codeforces (keyless public `contest.list` API, upcoming
  rounds only; guarantees the CP category is never empty out of the box),
  MLContests (keyless; `data-competitions` embedded JSON on mlcontests.com, the
  "CTFtime of AI" - keyless Kaggle/Zindi/Codabench/HuggingFace/DrivenData/AIcrowd
  coverage, `category: .ai`, open comps only), ybox.vn (embedded
  `__INITIAL_STATE__` JSON, not HTML scraping; ybox is the VN
  design/other/scholarship lane and does NOT feed CP/CTF/AI - those reach the
  Vietnam filter from the aggregators above via region detection), Contest
  Watchers (RSS), Brave Search + Google CSE (lead discovery
  over the `SearchCatalog` query set, gated by `SearchHitMapper`), Fake
  (self-test). DuckDuckGo was evaluated and rejected: its scrapeable endpoints
  serve bot-challenge pages (HTTP 202) and it has no official web-results API.
- `Sources/CompHuntKit/Engine/` - `Classifier` (category + Vietnam detection;
  VN detection = `.vn` host, VN place names, and a `vietnamContestBrands`
  allowlist that tags VN technical contests - VNOI, WhiteHat, Zalo, SVATTT -
  arriving from clist/CTFtime/Codeforces under a non-.vn host and English title),
  `RefreshEngine` (TaskGroup fan-out, dedupe/upsert preserving `firstSeen`,
  prune of untracked dateless rows unseen 14 days), `SourceRegistry`
  (`SourceID`: display names, config hints, metered-search flag; the app builds
  its source list from it per refresh)
- `Sources/CompHuntKit/YouTrack/` - sink filing COMP issues (a small menu item
  in the app, not a headline button)
- `Sources/CompHuntKit/Query/` - `SearchQuery` (operators `category:`, `region:`,
  `source:`, `status:`, `deadline:`, plus results, diagnosis, suggestions) plus
  the on-device "Ask" natural-language filter:
  `NLFilterGenerator` + `GeneratedQuery` (Apple FoundationModels, no API key,
  free on both platforms - folded in from the retired comphunt-pro overlay
  2026-08-01; nCompHunt is free forever, there is no pro build)
- `Sources/CompHuntKit/Support/` - `SecretsReader` (resolves Keychain-first,
  then the `~/.claude/secrets.yml` fallback), `CredentialStore`
  (`KeychainCredentialStore`), `SecretsImporter` (one-time secrets.yml -> Keychain
  migration), HTTP wrapper, `ICSBuilder` (single-contest `.ics` export for the
  Add to Calendar action), `CalendarEventPlan` (reconciliation model for the
  EventKit calendar sync; the sync itself is app-layer in
  `App/Sources/CalendarSyncService.swift`, since EventKit is unavailable to the
  sandboxed library target), `CategoryStyle` (the ONE category color/short-label
  mapping + `CategoryDot`; app rows, chip row, and widget all read it - never
  hardcode a category color in a view again), `ReminderPlan` + `DigestPlan` (the
  two notification planners, see the notification model below), `DashboardStats`
  (all dashboard counting; the view renders and derives nothing)
- `App/` - SwiftUI app: main window is a `NavigationStack` (the three-pane
  NavigationSplitView is gone): `CategoryChipRow` above the list writes the
  category into the query string, one merged sort/group/region toolbar menu, an
  "Ask" sparkles button (`NLFilterGenerator`, disabled with a reason when Apple
  Intelligence is off), per-row context menu = `CompetitionActionsMenu`.
  Inside that stack the layout is per-platform. iOS is a single panel and rows
  tap-to-expand in place (`CompetitionExpandedView` inline, no push). macOS has
  two styles behind a toolbar toggle (`ListStyle` @AppStorage `list.style`):
  `list` is an `HSplitView` of `CompetitionListPane` + `CompetitionDetailPane`,
  `table` is a full-width sortable `CompetitionTablePane` with the detail in an
  `.inspector`. One `selectedID` drives list, table, detail, inspector and the
  widget deep link - different projections of one state, never separate states,
  and table header sorting writes the same `ListSort` the toolbar menu reads.
  Group by is disabled in table style because a table is flat by design.
  A leading "Marked" chip (divided off from the category chips - it is a second
  axis, not a sixth category) writes `status:any`. A Dashboard toolbar button
  opens `DashboardView`, its own `Window` scene on macOS and a sheet on iOS,
  the same split Settings uses.
  Plus MenuBarExtra +
  refresh timer + UNUserNotifications + `CalendarSyncService` (opt-in EventKit
  sync into a dedicated "nCompHunt" calendar; needs
  `NSCalendarsFullAccessUsageDescription` + the `personal-information.calendars`
  entitlement). iOS shares all of it via `#if os` splits except: MenuBar files
  are excluded from CompHuntiOS; Settings is a toolbar-gear sheet in MainWindow
  (no Settings scene); "Add to Calendar" presents EventKitUI's
  `EKEventEditViewController` (`EventEditSheet.swift`, same `CalendarEventPlan`
  shape as the macOS .ics path); `BackgroundRefresh.swift` (BGAppRefreshTask id
  `com.nhannht.ncomphunt.refresh`, `.backgroundTask` scene modifier) stands in
  for the always-running macOS refresh timer; secrets import uses
  `.fileImporter`. App Group id branches in `AppGroup.swift`: team-prefixed on
  macOS, bare `group.com.nhannht.ncomphunt` on iOS (each platform's
  entitlements files match). The YouTrack curl fallback is macOS-only (iOS
  cannot shell out; a Cloudflare 1010 block surfaces as its 403). Settings has per-source checkboxes (UserDefaults
  `source.<id>.enabled` via `SourcePreferences`) plus an API Keys section that
  stores keys in the Keychain (`CredentialStore`) with an "Import from
  secrets.yml" migration; search sources additionally gate on a 24h window
  (`lastSearchFetch`) recorded only after a successful search run.

## Secrets and config (never hardcode, never commit)

- Keys resolve Keychain-first: the app stores them in the macOS Keychain
  (`KeychainCredentialStore`, managed under Settings > API Keys). The flat
  `~/.claude/secrets.yml` (parsed with Yams, UPPER_SNAKE, "your-" placeholder
  values rejected) is the dev/CLI fallback and the source for the one-time
  `SecretsImporter` migration. Every shipped build is sandboxed
  (`ENABLE_APP_SANDBOX: YES`, no DMG/MAS split), so the automatic path read of
  that file never succeeds in the app - it is Keychain-only there. The
  `SecretsImporter` migration still works everywhere because `SettingsView`
  routes it through an `NSOpenPanel` plus `startAccessingSecurityScopedResource`,
  covered by the `files.user-selected.read-only` entitlement. Missing key = the source reports
  "skipped", run continues. Keys: `CLIST_USERNAME` + `CLIST_API_KEY` (clist.by),
  `BRAVE_API_KEY` (Brave Search API), `GOOGLE_CSE_KEY` + `GOOGLE_CSE_CX`
  (Google Programmable Search: API key + engine id with "search entire web").
- YouTrack base URL + bearer token: Keychain-first, same as the API keys. The
  `~/.claude.json` `mcpServers.youtrack.headers.Authorization` discovery (same
  as job-recon) is a `SecretsReader` fallback that only resolves outside the
  sandbox, so it applies to `swift test` and CLI use of `CompHuntKit`, never to
  the shipped app. `SecretsReader.defaultClaudeJSONPath` has no open-panel
  equivalent, unlike the secrets.yml importer.
- YouTrack sits behind Cloudflare that blocks non-browser clients (error 1010):
  URLSession uses a browser-like User-Agent; if blocked, shell out to `curl`.

## YouTrack

- Competitions the user decides to enter are filed into the `COMP` project via
  the "Track in YouTrack" item in the actions menu - one POST creating the
  issue with Type=Task in the same call (transient-failure-safe, mirrors
  job-recon `youtrack.py`). No auto-filing. Outcomes surface as notifications.

## The mark, and the notification model (2026-08-02)

`CompetitionStatus` (interested / applied / joined / done / dropped) is the app's
ONLY user-authored state. A competition carrying one is MARKED, and marking is
what earns it a reminder.

```
  every competition  ->  DigestPlan    ->  ONE post each morning (08:00 default)
                                           "6 closing this week - 2 running now"
                                           quiet morning = no post at all

  marked only        ->  ReminderPlan  ->  1 day + 1 hour before the deadline
                                           done/dropped keep the mark, stop firing
```

Rules that are easy to violate later:

- **Nothing unmarked ever notifies.** This inverted an opt-out model on
  2026-08-02 (COMP-40 shipped every competition subscribed, with a per-row Mute).
  There is no mute list any more, and reintroducing one means the default went
  wrong again.
- **The two planners stay separate.** A digest has no competition attached, so it
  cannot go through `ReminderPlan` without a fake row. They share only
  `Notifier.replace(prefix:with:)` and each owns its identifier prefix
  (`reminder.` / `digest.`), which is what stops one clearing the other.
- **Digest counts are computed relative to the morning they fire on**, not to
  now, and only 2 mornings are scheduled ahead. Longer lookahead means stale
  numbers; going quiet is the honest failure.
- **User state on `Competition` requires a prune exemption.** `statusRaw` and
  `trackedIssueID` are both spared in `CompetitionStore.prune`. The store is a
  rebuildable cache of the feeds; a mark is not rebuildable from anywhere.
- **Adding a stored property to `Competition` requires a new version in
  `CompetitionSchema.swift`.** The store shipped in v0.1-v0.3; an unversioned
  change traps at launch (`Attempting to set value for unknown key`), before
  there is any UI to report it in. `CompetitionSchemaV1` is frozen - never edit
  it, the migration matches stores against it.

## Conventions

- Swift 6 strict concurrency; sources return plain `CompetitionDTO` values,
  SwiftData writes happen in the engine/app layer.
- All status writes go through `AppModel.setStatus`, never a view's own model
  context, so the save and the reschedule cannot come apart.
- Fixture-based tests in `Tests/CompHuntKitTests/Fixtures/` - never hit the
  network in tests.
- Dedupe key: lowercased URL without query string or trailing slash.
- showcase/ must hold 2+ real screenshots before the product is called done.

## Website (separate repo, 2026-08-02)

The marketing site is NOT in this repo. It lives beside it at
`../website` (repo `nhannht/ncomphunt-website`), extracted with
`git-filter-repo` so its twelve commits kept their history. Its own
`CLAUDE.md` carries the stack, design rules, and deploy details - do not
re-document them here.

What this repo still owes the site:

- **Every GitHub release must upload an unversioned `ncomphunt.dmg` asset**
  alongside the versioned one. The site's download button points at the
  evergreen `releases/latest/download/ncomphunt.dmg`, so a missing
  unversioned asset breaks it silently, and no site rebuild can fix it.
- **Showcase images.** The site copies from `showcase/` into its own
  `public/screenshots/`. New App Store renders here mean a copy over there.
- **PRIVACY.md is a pointer, not the policy.** The real document is the
  website repo's `PRIVACY.md`, because its `/privacy` page is the only thing
  that reads it. Edit it there.

Distribution (owned here): direct GitHub release DMG + Homebrew cask
`nhannht/homebrew-tap` (Developer ID, notarized), and the Mac App Store
(app id 6791654003, sandboxed build).
