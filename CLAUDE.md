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
  panel). NOTE: the SHIPPED 1.2.0 set (`showcase/appstore/as01..as10.png`,
  10 renders) was code-composed to the same recipe from user CleanShots
  because the Sketch MCP was down that session; the artboards still show the
  1.1.0-era five. Backport tracked in COMP-52 - rebuild the ten as real
  artboards and sync this map in the same turn.

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
  return), `Competition` (SwiftData `@Model`, `#Unique` on `key`; persists
  `categoryTagsRaw` - the classifier's WHOLE answer, comma-joined - with
  `categoryRaw` always its first entry or `other`, a projection enforced by
  the `tags:` initializer and the `categoryTags` setter. Filtering is
  containment via `belongs(to:)` - sidebar, chips, `category:` operator,
  widget/menu-bar `upcomingContests` all ask "does this row carry the tag",
  so a poetry+music+photography row surfaces under writing AND media.
  Single-slot surfaces - group-by, table column, row dot, dashboard tallies -
  stay on the `category` projection; dashboard counts partition on purpose so
  they sum to the total), `Category`
  (cp/ctf/ai/hackathon/design/writing/media/business/academic/other),
  `Region` (vietnam/global), `UserProfile` (COMP-16: single-row `@Model` -
  interest weights, CF handle+cached rating, weekly hours, prize floor,
  preferred region; schema V4. Deliberately NOT columns on `Competition`,
  which prune deletes. `ProfileSnapshot` is its Sendable value form the
  scorer reads; `suggestedInterests(from:)` seeds weights from marking
  history - interested 1, applied 2, joined/done 3, dropped -1, normalized -
  as an EXPLICIT Settings action, never continuous inference, so the ranked
  list cannot reshuffle unasked)
- `Sources/CompHuntKit/Sources/` - one file per source implementing
  `CompetitionSource` (`fetch() async throws -> [CompetitionDTO]`): CTFtime,
  Devpost, clist.by, Codeforces (keyless public `contest.list` API, upcoming
  rounds only; guarantees the CP category is never empty out of the box;
  `CodeforcesRating` rides the same keyless API's `user.info` to cache the
  profile's rating on the refresh cycle - COMP-17, failure is non-fatal),
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
- `Sources/CompHuntKit/Engine/` - `Classifier` (`tags(for:)` returns EVERY
  category the text supports, in priority order; `category(for:)` is a
  projection of it - `tags.first ?? .other` - never a second decision. Keyword
  needles are word-anchored; a `*` prefix additionally allows a word-FINAL
  match (what makes `picoCTF` a CTF while `ImpactForge` is not) and a `*`
  suffix a word-INITIAL match (`photograph*` reaches photography and
  photographer; English inflects, Vietnamese compounds, so only English
  needles carry stems). `details` is a FALLBACK haystack consulted only when
  title+tags say nothing - never merged into one haystack, because marketing
  prose name-drops ("AI is changing real estate") and merged haystacks flipped
  leading tags on rows the title had already answered (measured 2026-08-03,
  ybox `.other` 53 -> 22 of 117 with zero lead-tag changes). A source that
  declares its own kind ends the search. The last four categories exist
  because 81 rows sat in `.other`, all from ybox, 88% of them naming an
  activity the taxonomy had no case for - see
  `../research/comp-27-classification/`. The vocabulary is CLOSED on purpose:
  multi-tag assignment from the fixed enum, never an open tag namespace - the
  research measured open vocabularies fragmenting (4 names for photography, a
  typo becoming a permanent bucket) and the on-device model was taken out of
  the shipped classification path entirely (pass 10: one cosmetic prompt
  rewording swung output 2x). Also Vietnam detection;
  VN detection = `.vn` host, VN place names, and a `vietnamContestBrands`
  allowlist that tags VN technical contests - VNOI, WhiteHat, Zalo, SVATTT -
  arriving from clist/CTFtime/Codeforces under a non-.vn host and English title),
  `RefreshEngine` (TaskGroup fan-out, dedupe/upsert preserving `firstSeen`,
  prune of untracked dateless rows unseen 14 days), `SourceRegistry`
  (`SourceID`: display names, config hints, metered-search flag; the app builds
  its source list from it per refresh), `PrizeNormalizer` (COMP-13: free-text
  prize strings to one comparable USD number - `PrizeValue` with
  `topPrizeUSD`/`totalPoolUSD`/`nonCash`. Extraction, never comprehension: a
  number counts only when a currency marker touches it, ambiguity resolves to
  nil, static FX table refreshed per release, deliberately NO model - the value
  is derived on read (`Competition.prizeValue`, memoized, never persisted), so
  nondeterminism would reshuffle the ranked list. ybox serves amounts in
  TITLES, so `value(prize:title:)` falls back there, tagged `.inferred`.
  Coverage is pinned against the live-store snapshot in
  `Fixtures/prize-corpus.json` - a rule change that moves real-world coverage
  fails the CorpusCoverage suite in either direction), `EffortEstimator`
  (COMP-14: expected-hours band per category from wall duration -
  `EffortEstimate` with `hours: ClosedRange`, `confidence`, `basis`. The trap
  it exists to avoid is wall-versus-effort confusion: a 4-week AI contest is a
  20-60h committed band, never its 672h wall; a 48h jeopardy CTF is a
  12-19h slice; a CP round IS its wall. Missing dates degrade to a
  low-confidence category default, never nil, so dateless rows still rank),
  `FitScorer` (COMP-15: profile + competition -> `RankedCompetition`
  `{score 0-100, headline, reasons}` - nine components each add a signed
  delta to a base of 50 and EVERY non-zero component emits a reason;
  missing input SKIPS a component, never zeroes the score. Deterministic,
  no model, per COMP-5. `FitContext` holds the adopted `ProfileSnapshot` -
  process-wide because sort comparators only see the Competition, same
  shape as PrizeNormalizer's cache; the app re-adopts on profile edits so
  the list re-ranks live. Busy `[DateInterval]`s ride a second FitContext
  slot (COMP-18), read from EventKit by the app layer -
  `CalendarSyncService.busyIntervals` is prompt-free, full-access-only, and
  excludes the app's own nCompHunt calendar plus all-day/free events, so no
  access degrades to neutral and a synced competition never conflicts with
  itself. `FitScorer.topPick` (COMP-19) ranks the `upcomingContests`
  candidate set and returns the best-fit row with its verdict - ties break
  to the sooner date - for the menu-bar countdown and the widget's featured
  row; `WidgetSnapshot.topPick` carries it across the App Group boundary as
  plain values, optional end to end so a stale or older-build snapshot
  still decodes)
- `Sources/CompHuntKit/YouTrack/` - sink filing COMP issues (a small menu item
  in the app, not a headline button)
- `Sources/CompHuntKit/Query/` - `SearchQuery` (operators `category:`, `region:`,
  `source:`, `status:`, `deadline:`, plus results, diagnosis, suggestions) plus
  the on-device natural-language filter:
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
  mapping + `CategoryDot`, whose `size` defaults to the 6pt inline hint and goes
  to 10pt in the sidebar where the dot IS the identity; app rows, sidebar, chip
  row and widget all read it - never hardcode a category color in a view
  again), `TextLanguage` + `TranslationPair` (which language is a row's text
  in and should this reader be offered a translation - reader-relative
  direction, never hardcoded vi->en, nil when languages match or detection is
  unsure; the only NaturalLanguage capability that works for Vietnamese),
  `ReminderPlan` + `DigestPlan` (the
  two notification planners, see the notification model below), `ArrivalLog`
  (COMP-49: when the user comes back, learned by watching - the pure half of the
  digest's timing, applied by `App/Sources/Presence.swift`), `DashboardStats`
  (all dashboard counting; the view renders and derives nothing)
- `App/` - SwiftUI app: `MainWindow.shell` is the one place the platforms
  differ. macOS is a two-column `NavigationSplitView` whose sidebar is
  `CategorySidebar`; iOS is a `NavigationStack` and keeps `CategoryChipRow`
  above the list, which is the phone's category filter only. Both write the
  category into the query string rather than holding their own state. The
  sidebar marks each kind with a `CategoryDot`, never an SF Symbol: ten glyphs
  in a column read as ten unrelated pictures, and the dot is the marker every
  other surface already uses. (The iOS chip row is the opposite call and both
  are deliberate: idle chips are icon-only `CompetitionFilter.systemImage`
  glyphs so all eleven fit the phone's width, and the selected chip names
  itself in a tinted capsule.) Then one merged sort/group/region toolbar menu,
  per-row context menu = `CompetitionActionsMenu`. Natural-language search has
  NO button (COMP-47): a sentence typed into the search field is resolved by
  `NLFilterGenerator` after a debounce and OFFERED as a sparkles suggestion
  row showing readable filters; accepting writes `serialized()` through the
  one query path. Token text or an empty read = no row. Model off + a typed
  sentence = an informational row naming the reason (COMP-50, dimmed sparkles,
  never tappable, never auto-applies; the actionable button is the Settings >
  Language status row). Never auto-apply the model's reading or rewrite typed
  text unasked, and never fail silent on an OS-gated capability - the pattern
  is the notifications Permission row, and `SearchQuery.isSentenceLike` is the
  ONE spelling of the sentence rule for both the interpret and the explain
  branches.
  Inside the detail column the layout is per-platform. iOS is a single panel and
  rows tap-to-expand in place (`CompetitionExpandedView` inline, no push). macOS has
  two styles behind a toolbar toggle (`ListStyle` @AppStorage `list.style`):
  `list` is an `HSplitView` of `CompetitionListPane` + `CompetitionDetailPane`,
  `table` is a full-width sortable `CompetitionTablePane` with the detail in an
  `.inspector`. One `selectedID` drives list, table, detail, inspector and the
  widget deep link - different projections of one state, never separate states,
  and table header sorting writes the same `ListSort` the toolbar menu reads.
  Group by is disabled in table style because a table is flat by design.
  Both detail surfaces translate automatically (COMP-28): a row whose
  detected language differs from the user's reading language opens already
  translated, original one click away behind the same Show Original toggle.
  The reading language is a Settings > Translation picker (`translation.language`,
  default English - the index's lingua franca, NOT the system locale, so
  out-of-the-box behavior is identical on every machine), auto is a toggle
  (`translation.auto`, default on; off keeps a manual Translate button). The
  picker lists `LanguageAvailability.supportedLanguages`, so it can never
  offer a pair the OS would refuse. `TranslateControl.swift` hosts the
  Translation-framework session (`@preconcurrency import` here and in
  SettingsView - the SDK leaves `TranslationSession`/`LanguageAvailability`
  un-annotated for Sendable). Display-only and never persisted, so a refresh
  rewriting source text cannot strand a stale translation; nothing appears at
  all when languages already match or the pair is unsupported. The expanded
  view adds the translated title as its own line because the collapsed row
  above keeps the original as heading. List rows stay original on purpose -
  titles are identifiers there.
  A leading "Marked" row, sectioned off above the kinds on macOS and divided off
  from the chips on iOS because it is a second axis and not another kind, writes
  `status:any`. A Dashboard toolbar button
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
  cannot shell out; a Cloudflare 1010 block surfaces as its 403). Settings is
  tabbed on macOS (the `Settings` scene renders `TabView` as native toolbar
  tabs: Profile, Sources+Refresh, API Keys, YouTrack, Calendar, Notifications,
  Language - the last holding BOTH on-device language sections, Translation
  and Natural-language search, whose Apple Intelligence status row mirrors
  the notifications Permission row (macOS gets an open-settings button, iOS
  status text only: no public deep link to that pane exists) - one private
  subview per tab/section; iOS reuses the same subviews as
  one grouped list, its own settings idiom in a sheet; the API Keys tab bumps
  `settings.configRevision` AppStorage so the Sources tab re-reads Keychain
  `isConfigured` across the tab boundary). Settings has per-source checkboxes (UserDefaults
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
  every competition  ->  DigestPlan    ->  ONE post a day, timed by observation
                                           "6 closing this week - 2 running now"
                                           nothing to say = no post at all

  marked only        ->  ReminderPlan  ->  1 day + 1 hour before the deadline
                                           done/dropped keep the mark, stop firing
```

The digest's TIMING comes from `ArrivalLog` + `App/Sources/Presence.swift`
(COMP-49, 2026-08-05), never from a clock the user set:

```
  presence samples (screen awake AND on console)
        |
        +-- gap >= 5h then present again = ARRIVAL
                 |
     macOS  -----+--> post NOW, at most once a calendar day
     iOS         +--> feed the learned hour, schedule there
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
- **Digest counts are computed for the moment the post is FOR**, which on macOS
  is now and on iOS is the scheduled morning. `DigestPlan.make(for:at:)` is the
  one constructor; nothing is ever built for a moment far ahead, so there is no
  stale-numbers hazard left to manage.
- **The digest is never scheduled on macOS.** It is posted on arrival. A
  scheduled post is exactly what failed: on 2026-08-05 the 08:00 request fell due
  while the Mac was in deep sleep from 07:51 to 08:06 and was never seen. Do not
  reintroduce a wall-clock trigger on macOS, and do not "fix" a missed digest by
  moving the hour - this Mac is asleep at every hour you could name.
- **App liveness is NOT user presence.** A sleeping Mac dark-wakes every few
  minutes all night and nCompHunt runs through every one of them (measured
  02:41, 06:32, 07:38, 07:49, 08:06 on 2026-08-05). Presence is the SCREEN being
  awake plus the session being on console; iOS uses foreground-and-active, which
  keeps a 3am background refresh from teaching the learned hour a habit nobody
  has. Any timing rule built on "time since the app last ticked" fires at 02:41.
- **No picker for the digest, ever.** The on/off toggle is a decision and stays;
  a time, a threshold, or a frequency is derived from observation and shown
  read-only. The 5-hour absence threshold is internal and is never surfaced.
  User directive 2026-08-05: the app is not important enough to make anyone
  think about it.
- **User state on `Competition` requires a prune exemption.** `statusRaw` and
  `trackedIssueID` are both spared in `CompetitionStore.prune`. The store is a
  rebuildable cache of the feeds; a mark is not rebuildable from anywhere.
- **Adding a stored property to `Competition` requires a new version in
  `CompetitionSchema.swift`.** The store shipped in v0.1-v0.3; an unversioned
  change traps at launch (`Attempting to set value for unknown key`), before
  there is any UI to report it in. Every version except the NEWEST nests a
  frozen copy of the model (V1 as shipped through v0.3.0, V2 through v1.0.x) -
  never edit them, the migration matches stores against them. Only the newest
  version points at the live type, and adding V(n+1) means freezing V(n)'s
  copy in the same turn: a version aliased to a live type that later grows a
  property no longer describes any store on disk. Rows migrated into V3 have
  empty `categoryTagsRaw`; `CompetitionStore.backfillMissingTags` (run every
  refresh, one-time per row by construction) fills them keeping the stored
  category FIRST, because the store does not record which categories were
  source-declared and re-deriving one from text would downgrade it - same
  reasoning that scopes `reclassifyUnplaced` to `.other`.

## Live Activity (iOS only, COMP-37)

One followed contest is glanceable in the Dynamic Island and on the Lock
Screen. `ContestActivityPlan` (kit, pure, beside `WidgetSnapshot`) decides the
face - registration countdown, pre-start countdown, or running-with-progress -
and its `staleDate`; `ContestActivities` (app) starts/updates/ends via
ActivityKit; `ContestActivityWidget` (extension, `#if os(iOS)` since the
`Widget/` dir compiles into both widget targets) renders. Entry point is the
"Follow Countdown" action in the actions menu; following and marking are
independent axes. Rules that are easy to violate later:

- **Timer-driven only.** `Text(timerInterval:)` / `ProgressView(timerInterval:)`
  are ticked by the system; there are NO push updates and no server. Face flips
  are applied by `reconcile` on every refresh and on foregrounding, and
  `staleDate` dims the activity honestly in between.
- **The 8-hour system cap is a plan rule, not a render rule.** A running face
  is only offered when the whole contest fits inside the cap; multi-day events
  (CTFs) count down to the start and then end. Do not "fix" a long CTF by
  rendering past the cap - the system cuts the activity off anyway.
- **`Activity.activities` IS the follow state.** No stored follow list; a
  UserDefaults mirror would be a copy kept in sync by hand.
- **No `isCurrent` guard in the plan.** A past registration deadline with no
  end date reads as "over" for browsing, but a follower registered - the start
  countdown is the face they are waiting for.

## Accessory widget families (iOS only, COMP-33)

The upcoming-contests widget adds `accessoryInline` / `accessoryCircular` /
`accessoryRectangular` for the Lock Screen - the iOS incarnation of the macOS
menu-bar countdown (`MenuBarStatus`, which stays macOS-only UI): shortCode +
ticking `CountdownText` over the snapshot's `topPick`, falling back to the
soonest contest. Views live in `ContestAccessoryViews.swift`, whole file
`#if os(iOS)`; the macOS extension keeps exactly `.systemSmall` +
`.systemMedium`.

- **One `WidgetView` case per family.** A family added to `supportedFamilies`
  without its own switch case silently renders the un-tuned default layout.
- **Identity is text, never `CategoryDot`.** Accessory rendering is vibrant
  and desaturated - color carries nothing on the Lock Screen.
- **`CountdownText` is the one countdown.** Shared with the Live Activity
  (`App/Widget/CountdownText.swift`); accessoryInline concatenates its bare
  `.text` because inline renders exactly one line of text.

## Motion (one vocabulary, COMP-46)

`App/Sources/Views/Motion.swift` is CategoryStyle for animation: three named
curves (`state` for flips and digit rolls, `layout` for size/order changes,
`emphasis` for the rare celebration) plus `Motion.reveal(reduced:)` for
conditional content. Rules that are easy to violate later:

- **Never a literal spring in a view.** Pick a tier from `Motion`; if none
  fits, grow the vocabulary there, not at the use site.
- **Movement needs a Reduce Motion fallback.** Any transition that slides,
  scales, or grows pairs with `accessibilityReduceMotion` at the use site
  (`Motion.reveal(reduced:)` encodes it; the dashboard bars skip their grow).
  Digit rolls and cross-fades are exempt.
- **A number that can change rolls.** `contentTransition(.numericText())` on
  every changing figure - whenLine, prize, fit, tiles, menu-bar tick. A
  static-looking number is a bug in a countdown app.
- **The control is its own progress indicator.** The AI suggestion row
  shimmers (`variableColor`) while the model reads, and Refresh rotates in
  place while busy; never swap a control out for a `ProgressView`.

## App Intents: Siri, Spotlight, Shortcuts (COMP-24)

`App/Sources/Intents/` exposes the index to the system - and on macOS 26 to
the Shortcuts "Use Model" action, so people can pipe competitions through
Apple Intelligence in automations we never wrote. Entities expose only what
the app already stores; no new data collection.

- `CompetitionEntity` (AppEntity + IndexedEntity): id IS the dedupe key, so
  Spotlight taps, intent results, widget taps, and reminders all route through
  `competitionDeepLink(key:)`. `CompetitionQuery` resolves through the ONE
  `AppModel`, registered with `AppDependencyManager` in `CompHuntRoot.init` -
  never a second `ModelContainer` on the same store file.
- Intents: `NextCompetitionIntent` (dialog via `whenLine`),
  `UpcomingCompetitionsIntent` (returns entities, not prose - that is what
  "Use Model" consumes), `OpenCompetitionIntent` (returns
  `OpenURLIntent(competitionDeepLink(...))` - one open path).
- `CategoryOption` is the app-layer AppEnum mirror of `CompetitionCategory`
  (kit stays framework-free); its display names must match `displayName`.
- Spotlight donation is whole-set delete + reindex after every refresh in
  `AppModel.donateToSpotlight` - self-healing like the reminders, prune-safe
  by construction. Siri phrases must contain the app name, so "next CTF"
  ships as "next CTF in nCompHunt".
- Testing intents on this Mac (learned 2026-08-04): Shortcuts refuses an
  ad-hoc-signed app with "couldn't communicate with the app", so a Debug
  build installed to /Applications must be re-signed first:
  `codesign --force --deep --preserve-metadata=entitlements -s "Developer ID
  Application" /Applications/nCompHunt.app`. Headless check: author a one-
  action .shortcut plist (`WFWorkflowActionIdentifier` =
  `com.nhannht.ncomphunt.<IntentTypeName>`, params like
  `{"category": "ctf"}`), `shortcuts sign --mode anyone`, import, then
  `shortcuts run <name> -o out.txt` and assert on the output.

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
