# CompHunt

Native macOS app that finds and indexes competitions - competitive programming,
AI challenges, CTFs, hackathons, and design contests - in Vietnam and globally,
and lists them with sort and group controls, category filters, and native
notifications for new finds.

## Sources

Every source has an enable checkbox in Settings; a failing or unconfigured
source is skipped, never kills a refresh.

- CTFtime API v1 - the canonical worldwide CTF calendar
- Devpost - global hackathons with prizes, themes, and deadlines
- clist.by API v4 - aggregator covering Codeforces, AtCoder, LeetCode, CodeChef,
  Kaggle, HackerRank and hundreds more (requires a free API key)
- ybox.vn - Vietnamese student and professional competitions
- Contest Watchers - creative and design competition directory (RSS)
- Brave Search + Google Programmable Search - lead discovery over a fixed
  bilingual query catalog, at most once per day to stay inside free API quotas
  (both need free keys; leads with no dates age out after 14 days unseen)

## Actions

Right-click any row (or use the detail header menu): open page, share via the
system sheet (Notes, Messages, Mail, AirDrop), copy link, add to Calendar as an
.ics import, and file into the YouTrack `COMP` project (one Task issue per
competition, deep-linked back from the app). Configuration is discovered from
local machine files; see CLAUDE.md.

## Layout

- `Sources/CompHuntKit/` - core library: models, source plugins, refresh engine,
  YouTrack sink (SwiftPM)
- `Tests/CompHuntKitTests/` - fixture-based parser, classifier, and dedupe tests
- `App/` - SwiftUI app (main window + menu bar extra), project generated with
  XcodeGen from `App/project.yml`

## Build

- Tests: `swift test`
- App: `cd App && xcodegen generate && xcodebuild -project CompHunt.xcodeproj -scheme CompHunt build`

## Requirements

- macOS 15+, Xcode 26+, XcodeGen
