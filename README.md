# CompHunt

Native macOS app that finds and indexes competitions - competitive programming,
AI challenges, CTFs, hackathons, and design contests - in Vietnam and globally,
and lists them with deadline-first sorting, category filters, and native
notifications for new finds.

## Sources

- clist.by API v4 - aggregator covering Codeforces, AtCoder, LeetCode, CodeChef,
  Kaggle, HackerRank and hundreds more (requires a free API key)
- CTFtime API v1 - the canonical worldwide CTF calendar
- Devpost - global hackathons with prizes, themes, and deadlines
- ybox.vn - Vietnamese student and professional competitions
- Contest Watchers - creative and design competition directory (RSS)

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
