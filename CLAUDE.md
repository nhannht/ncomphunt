# CLAUDE.md

nCompHunt - native macOS (Swift/SwiftUI) competition indexer. Display/product
name is nCompHunt (bundle id com.nhannht.ncomphunt, DMG slug ncomphunt); the
internal code names - target, scheme, xcodeproj, CompHuntKit module - remain
CompHunt. Finds and lists
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
- `App/CompHunt.xcodeproj` is generated from `App/project.yml` (XcodeGen) and
  gitignored - edit `project.yml`, never the xcodeproj.

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
- `Sources/CompHuntKit/Support/` - `SecretsReader`, HTTP wrapper, `ICSBuilder`
  (calendar export used by the Add to Calendar action; no EventKit)
- `App/` - SwiftUI app: main window (NavigationSplitView, sort/group toolbar
  menu, per-row context menu = `CompetitionActionsMenu`) + MenuBarExtra +
  refresh timer + UNUserNotifications. Settings has per-source checkboxes
  (UserDefaults `source.<id>.enabled` via `SourcePreferences`); search sources
  additionally gate on a 24h window (`lastSearchFetch`) recorded only after a
  successful search run.

## Secrets and config (never hardcode, never commit)

- All keys live flat in `~/.claude/secrets.yml` (parsed with Yams, UPPER_SNAKE,
  "your-" placeholder values rejected). Missing key = the source reports
  "skipped", run continues. Keys: `CLIST_USERNAME` + `CLIST_API_KEY` (clist.by),
  `BRAVE_API_KEY` (Brave Search API), `GOOGLE_CSE_KEY` + `GOOGLE_CSE_CX`
  (Google Programmable Search: API key + engine id with "search entire web").
- YouTrack base URL + bearer token: read from `~/.claude.json`
  `mcpServers.youtrack.headers.Authorization` (same discovery as job-recon).
- YouTrack sits behind Cloudflare that blocks non-browser clients (error 1010):
  URLSession uses a browser-like User-Agent; if blocked, shell out to `curl`.

## YouTrack

- Competitions the user decides to enter are filed into the `COMP` project via
  the "Track in YouTrack" item in the actions menu - one POST creating the
  issue with Type=Task in the same call (transient-failure-safe, mirrors
  job-recon `youtrack.py`). No auto-filing. Outcomes surface as notifications.

## Conventions

- Swift 6 strict concurrency; sources return plain `CompetitionDTO` values,
  SwiftData writes happen in the engine/app layer.
- Fixture-based tests in `Tests/CompHuntKitTests/Fixtures/` - never hit the
  network in tests.
- Dedupe key: lowercased URL without query string or trailing slash.
- showcase/ must hold 2+ real screenshots before the product is called done.
