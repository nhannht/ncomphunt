# App Store Connect metadata - nCompHunt v1.0.0

Paste-ready fields for App Store Connect. Character counts are stated next to
each length-limited field and were verified by counting.

## App name (9 / 30)

nCompHunt

## Subtitle (28 / 30)

Track every contest information

## Promotional text (164 / 170)

Competitive programming, AI challenges, CTFs, hackathons, and design contests - found, sorted, and waiting in your menu bar. No account, no server, all on your Mac.

## Description (2093 / 4000)

nCompHunt is a native macOS app that finds competitions and keeps them in front of you: competitive programming rounds, AI and machine-learning challenges, CTF security games, hackathons, and design contests, Vietnam-first and global.

It is built to live on your Mac. A SwiftUI main window gives you category and region filters plus sort and group controls. A menu bar extra keeps the next deadlines one click away. A desktop widget shows what is coming up without opening the app, and native notifications tell you the moment a new contest is found. Turn on calendar sync and a dedicated Apple Calendar keeps every deadline updated in place as contest details change, or add a single contest with one action as an .ics import. Share any listing through the standard macOS share sheet.

Your data stays yours. There is no account to create, no telemetry, no analytics, and no back-end server between you and the sources. The app fetches listings directly, and the index it builds never leaves your Mac.

Sources that work the moment you open the app, no setup required:
- CTFtime - the worldwide CTF calendar
- Devpost - global hackathons with prizes and deadlines
- Codeforces - upcoming competitive-programming rounds
- MLContests - open AI and ML competitions across several platforms
- ybox.vn - Vietnamese design, scholarship, and general-interest contests
- Contest Watchers - a creative and design competition directory

Want broader coverage? Add your own free API keys in Settings to switch on clist.by, which brings hundreds more programming contests, and optional web-search discovery. Keys are stored in the macOS Keychain, never in a plain file, and are sent only to the service they belong to. Every source has an on/off switch, and a source that fails or is unconfigured is simply skipped, never stopping the rest of a refresh.

Right-click any contest to open its page, copy the link, share it, add it to your calendar, or file it into YouTrack if you use it.

nCompHunt is free and open source under the MIT license. It requires macOS 15 or later, keeps no account, and stays quietly obsessive about deadlines so you do not have to be.

## Keywords (99 / 100)

hackathon,ctf,competitive programming,coding,ai challenge,machine learning,design,vietnam,developer

## What's New in 1.0.0

nCompHunt makes its Mac App Store debut.

This release moves API key management into the app. Enter your optional keys for clist.by and web-search discovery under Settings > API Keys, where they are stored securely in the macOS Keychain instead of a plain file. A one-tap import brings over any existing configuration. Includes the usual round of fixes and refinements.

## Support URL

https://github.com/nhannht/ncomphunt/issues

## Marketing URL

https://ncomphunt.nhannht.io.vn

## Privacy Policy URL

https://ncomphunt.nhannht.io.vn/privacy

## App Privacy (nutrition label questionnaire)

Data Not Collected - the app collects no data of any kind (consistent with the
App Review notes below: no accounts, no analytics, no telemetry, no
developer-run server).

## Copyright

2026 Nguyen Huu Thien Nhan

## Category

- Primary: Productivity
- Secondary: Developer Tools

## App Review notes

No account or login is required to use nCompHunt. The app refreshes automatically on launch (there is also a manual Refresh control) and the list populates from keyless public sources - CTFtime, Devpost, Codeforces, MLContests, ybox.vn, and Contest Watchers - with no configuration.

The API keys under Settings > API Keys (clist.by, Brave Search, Google Programmable Search) are optional enhancements that add more sources. The reviewer does not need to enter any keys to see a fully populated app.

The app links out to third-party competition pages, which open in the default browser. Calendar access is optional and user-initiated: it is requested only when the user turns on calendar sync in Settings or chooses Add to Calendar on a specific contest. Notifications are optional and requested only for new-contest alerts.

The app collects no data, uses no analytics, and operates no developer-run back-end server. All network requests go directly to the public competition sources listed above.
