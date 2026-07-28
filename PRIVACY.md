# Privacy Policy

Effective date: 2026-07-16\
Applies to: nCompHunt 1.0.x

nCompHunt is a native macOS app that finds and indexes competitions. This policy
explains what the app does and does not do with your data, as the app ships
today. It is not a promise about future versions: if a later release changes
what the app does, this policy is updated first and gets a new effective date.
See "Changes to this policy" at the end.

## What the current version collects

- nCompHunt does not collect, store, or transmit any personal data.
- It includes no analytics, no telemetry, no crash reporting, and no usage
  tracking.
- It has no accounts and no sign-in.
- It sends nothing to a developer-run server, because this version has no back
  end. Network requests go only to the public sources listed below.

## Network requests

nCompHunt makes network requests for one purpose only: to fetch public
competition listings from the sources you have enabled. Each source has an on/off
switch in Settings, and the app contacts only the sources that are turned on.

The sources it can contact are:

- CTFtime
- Devpost
- Codeforces
- MLContests
- ybox.vn
- Contest Watchers
- clist.by (only if you provide an API key)
- Brave Search and Google Programmable Search (only if you provide API keys)

These requests retrieve contest information. They are not used to send any
personal data about you.

## API keys you enter

Some optional sources (clist.by, Brave Search, Google Programmable Search)
require a free API key that you obtain yourself.

- Keys you enter are stored only in the local macOS Keychain on your Mac.
- A key is sent only to the service it belongs to, as part of fetching listings
  from that service.
- Keys are never sent to the developer or to any third party.

## On-device data

- The competition index that nCompHunt builds is stored locally on your Mac.
- Calendar integration uses Apple's EventKit. When you add a contest to your
  calendar or turn on calendar sync, that data stays on your device and in your
  own Apple Calendar. The app requests calendar access only when you initiate one
  of these actions.
- Notifications, when enabled, are delivered locally by macOS and are used only
  to alert you to newly found contests.

## Links to third-party sites

nCompHunt links out to competition pages hosted by third parties. Opening a link
takes you to that site in your browser, where that site's own privacy policy
applies. nCompHunt has no control over those sites.

## Children

nCompHunt does not collect any data from anyone, including children.

## Changes to this policy

This policy describes the version of nCompHunt named at the top. If a future
release changes what the app does with data - for example by adding a back-end
service, an account, or analytics - this policy is updated and republished at
this same location, with a new effective date and a new version range, before
that release ships. Nothing here should be read as a commitment that the app
will never gain those features.

## Contact

Questions about this policy can be raised as a GitHub issue:
https://github.com/nhannht/ncomphunt/issues
