# CLAUDE.md

CompHunt - native macOS (Swift/SwiftUI) competition indexer. Finds and lists
competitive programming contests, AI competitions, CTFs, hackathons, and design
contests, Vietnam-first and global. Sibling of `../job-tracker/recon` (the Python
job-recon engine) and follows its proven patterns: source plugins, normalized-URL
dedupe, a failing source never kills a run.

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
  Devpost, clist.by, ybox.vn (embedded `__INITIAL_STATE__` JSON, not HTML
  scraping), Contest Watchers (RSS), Fake (self-test)
- `Sources/CompHuntKit/Engine/` - `Classifier` (category + Vietnam detection),
  `RefreshEngine` (TaskGroup fan-out, dedupe/upsert preserving `firstSeen`)
- `Sources/CompHuntKit/YouTrack/` - Track-button sink filing COMP issues
- `Sources/CompHuntKit/Support/` - `SecretsReader`, HTTP wrapper
- `App/` - SwiftUI app: main window (NavigationSplitView) + MenuBarExtra +
  refresh timer + UNUserNotifications

## Secrets and config (never hardcode, never commit)

- clist.by username + API key: `~/.claude/secrets.yml` under the `clist:` key
  (parsed with Yams). Missing key = clist source reports "skipped", run continues.
- YouTrack base URL + bearer token: read from `~/.claude.json`
  `mcpServers.youtrack.headers.Authorization` (same discovery as job-recon).
- YouTrack sits behind Cloudflare that blocks non-browser clients (error 1010):
  URLSession uses a browser-like User-Agent; if blocked, shell out to `curl`.

## YouTrack

- Competitions the user decides to enter are filed into the `COMP` project via
  the Track button - one POST creating the issue with Type=Task in the same call
  (transient-failure-safe, mirrors job-recon `youtrack.py`). No auto-filing.

## Conventions

- Swift 6 strict concurrency; sources return plain `CompetitionDTO` values,
  SwiftData writes happen in the engine/app layer.
- Fixture-based tests in `Tests/CompHuntKitTests/Fixtures/` - never hit the
  network in tests.
- Dedupe key: lowercased URL without query string or trailing slash.
- showcase/ must hold 2+ real screenshots before the product is called done.
