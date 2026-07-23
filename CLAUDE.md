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
- `Sources/CompHuntKit/Support/` - `SecretsReader` (resolves Keychain-first,
  then the `~/.claude/secrets.yml` fallback), `CredentialStore`
  (`KeychainCredentialStore`), `SecretsImporter` (one-time secrets.yml -> Keychain
  migration), HTTP wrapper, `ICSBuilder` (single-contest `.ics` export for the
  Add to Calendar action), `CalendarEventPlan` (reconciliation model for the
  EventKit calendar sync; the sync itself is app-layer in
  `App/Sources/CalendarSyncService.swift`, since EventKit is unavailable to the
  sandboxed library target)
- `App/` - SwiftUI app: main window (NavigationSplitView, sort/group toolbar
  menu, per-row context menu = `CompetitionActionsMenu`) + MenuBarExtra +
  refresh timer + UNUserNotifications + `CalendarSyncService` (opt-in EventKit
  sync into a dedicated "nCompHunt" calendar; needs
  `NSCalendarsFullAccessUsageDescription` + the `personal-information.calendars`
  entitlement). Settings has per-source checkboxes (UserDefaults
  `source.<id>.enabled` via `SourcePreferences`) plus an API Keys section that
  stores keys in the Keychain (`CredentialStore`) with an "Import from
  secrets.yml" migration; search sources additionally gate on a 24h window
  (`lastSearchFetch`) recorded only after a successful search run.

## Secrets and config (never hardcode, never commit)

- Keys resolve Keychain-first: the app stores them in the macOS Keychain
  (`KeychainCredentialStore`, managed under Settings > API Keys). The flat
  `~/.claude/secrets.yml` (parsed with Yams, UPPER_SNAKE, "your-" placeholder
  values rejected) is the dev/CLI fallback and the source for the one-time
  `SecretsImporter` migration; the sandboxed App Store build cannot read it, so
  there it is Keychain-only. Missing key = the source reports
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

## Website (`website/`)

Marketing site, Apple liquid-glass style over the brand gradient
(#D825FC > #1C3D7A > #3574F0). Next.js 16 App Router + Tailwind v4 + shadcn
(nova preset) + React Bits components (FloatingLines, GlassSurface, GooeyNav,
SpecularButton, SplitText, GradientText, ShinyText, SpotlightCard, LogoLoop,
CardSwap, Carousel, Dock; Aurora, GlareHover, StarBorder installed but unused -
installed via `bunx shadcn add https://reactbits.dev/r/<Name>-TS-TW` into
`components/`). Site-wide background is FloatingLines (three.js,
`@types/three` dev dep) mounted fixed inset-0 -z-10 in `site/Background.tsx`
so it follows the viewport on scroll. Local customizations: FloatingLines
pointer listeners moved canvas -> window (canvas is pointer-events-none);
Carousel gained an optional `image` item field + glass palette; GooeyNav
dropped its black-backdrop gooey blend (leaks inside GlassSurface's
backdrop-filter stacking context) in favor of plain particles colored by
`--color-1..4` in globals.css.
bun only: `cd website && bun run build`; dev server binds loopback/Tailscale,
never 0.0.0.0. Page sections live in `components/site/`; copy and links in
`lib/site.ts` - `downloadUrl` is the evergreen DMG link
(`releases/latest/download/ncomphunt.dmg`); every GitHub release must upload an
unversioned `ncomphunt.dmg` asset alongside the versioned one so the site never
needs a rebuild per app release. Distribution is both direct (GitHub release DMG
+ Homebrew cask `nhannht/homebrew-tap`, Developer ID + notarized) and the Mac App
Store (app id 6791654003, sandboxed build).

Deployed at https://ncomphunt.nhannht.io.vn : `output: "export"` static build
(`images.unoptimized`, sitemap/robots `force-static`) rsynced from `out/` to
sg-hs `/var/www/ncomphunt.nhannht.io.vn`, nginx site `ncomphunt-nhannht-io-vn`
+ certbot TLS, Cloudflare proxied A record (zone nhannht.io.vn, token in
`~/.config/cloudflare/api_token.env`). Redeploy = build + same rsync. Note:
with `output: "export"`, `next start` no longer serves - preview `out/` with
any static server. Screenshots are copied from `showcase/`
into `website/public/screenshots/` (hero uses `raw/lightmodemain.png`; the
gallery uses the five `appstore/as*.png` renders). SEO: metadata + OpenGraph in
`app/layout.tsx`, JSON-LD SoftwareApplication in `app/page.tsx`,
`app/sitemap.ts`, `app/robots.ts`, favicon generated at `app/icon.png`.
