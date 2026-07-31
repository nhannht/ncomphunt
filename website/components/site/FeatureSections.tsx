"use client";

import {
  Bell,
  BellOff,
  CalendarCheck,
  CalendarDays,
  CalendarSync,
  Command,
  FileDown,
  Filter,
  Layers,
  LayoutDashboard,
  Link as LinkIcon,
  MousePointerClick,
  RefreshCw,
  ShieldCheck,
  SlidersHorizontal,
  Timer,
  type LucideIcon,
} from "lucide-react";
import FeatureVideo from "./FeatureVideo";

interface Bullet {
  icon: LucideIcon;
  text: string;
}

interface Feature {
  id: string;
  eyebrow: string;
  title: string;
  body: string;
  bullets: Bullet[];
  video: string;
}

const features: Feature[] = [
  {
    id: "how-it-works",
    eyebrow: "The engine",
    title: "Eight sources in. One list out.",
    body: "CTFtime, Devpost, Codeforces, MLContests, ybox.vn and more are fetched in parallel, deduplicated, and indexed into a single native list you can actually work through.",
    bullets: [
      { icon: RefreshCw, text: "Every refresh fans out to all sources at once" },
      { icon: Layers, text: "Duplicates collapse by normalized URL" },
      { icon: ShieldCheck, text: "A failing source is skipped, never fatal" },
    ],
    video: "hero",
  },
  {
    id: "menubar",
    eyebrow: "Menu bar extra",
    title: "The next deadline, one click away.",
    body: "A menu bar extra keeps the upcoming contests within reach all day. Skim what is closing soon and get back to work - no window, no dock switch.",
    bullets: [
      { icon: Command, text: "Lives in the menu bar, always one click away" },
      { icon: Timer, text: "Live countdowns on the nearest deadlines" },
    ],
    video: "menubar",
  },
  {
    id: "calendar",
    eyebrow: "Calendar sync",
    title: "Deadlines that keep themselves up to date.",
    body: "Turn on sync and every tracked deadline lands in a dedicated Apple Calendar. When an organizer moves a date, the event moves with it.",
    bullets: [
      { icon: CalendarSync, text: "A dedicated nCompHunt calendar, reconciled on every refresh" },
      { icon: CalendarCheck, text: "Changed deadlines update in place" },
      { icon: FileDown, text: "Or add a single contest as an .ics import" },
    ],
    video: "calendar",
  },
  {
    id: "notifications",
    eyebrow: "Notifications",
    title: "Know the moment something new lands.",
    body: "Background refreshes keep hunting while you work. When new competitions are found, a native macOS notification tells you - that is the whole interaction.",
    bullets: [
      { icon: Bell, text: "Native notifications for new finds" },
      { icon: BellOff, text: "Optional, and requested only when you turn them on" },
    ],
    video: "notifications",
  },
  {
    id: "actions",
    eyebrow: "Actions",
    title: "Right-click is a command center.",
    body: "Everything you do with a contest hangs off its row. Open the page, share it, copy the link, put it on the calendar, or file it into YouTrack.",
    bullets: [
      { icon: MousePointerClick, text: "Open, share, and copy from any row" },
      { icon: CalendarDays, text: "Add to Calendar as an .ics import" },
      { icon: LinkIcon, text: "Track in YouTrack when it is configured" },
    ],
    video: "actions",
  },
  {
    id: "widget",
    eyebrow: "Widget",
    title: "Glanceable from the desktop.",
    body: "An Upcoming Contests widget for the desktop and Notification Centre, in small and medium sizes, with a live countdown on what is next.",
    bullets: [
      { icon: LayoutDashboard, text: "Small and medium sizes" },
      { icon: Timer, text: "Counts down, rotates in the next contest" },
    ],
    video: "widget",
  },
  {
    id: "triage",
    eyebrow: "Filter, sort, group",
    title: "A list that bends to how you triage.",
    body: "Category and region filters, sort by deadline or first seen, group to see the week at a glance - in a real SwiftUI window that feels at home on macOS.",
    bullets: [
      { icon: Filter, text: "Six categories, two regions, one click each" },
      { icon: SlidersHorizontal, text: "Sort and group from the toolbar" },
    ],
    video: "filter",
  },
];

export default function FeatureSections() {
  return (
    <section id="features" className="scroll-mt-24">
      {features.map((feature, i) => {
        const flip = i % 2 === 1;
        return (
          <div key={feature.id} className="mx-auto max-w-6xl px-6 py-16 md:py-20">
            <div className="grid items-center gap-10 md:grid-cols-2 md:gap-16">
              <div className={flip ? "md:order-2" : undefined}>
                <p className="text-sm font-medium uppercase tracking-[0.2em] text-white/70">
                  {feature.eyebrow}
                </p>
                <h2 className="mt-3 text-3xl font-semibold tracking-tight text-white [text-wrap:balance] md:text-4xl lg:text-5xl">
                  {feature.title}
                </h2>
                <p className="mt-5 max-w-md leading-relaxed text-white/85">
                  {feature.body}
                </p>
                <ul className="mt-7 space-y-4">
                  {feature.bullets.map(bullet => (
                    <li key={bullet.text} className="flex items-start gap-3">
                      <span className="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-[#D825FC] to-[#3574F0]">
                        <bullet.icon className="size-4 text-white" />
                      </span>
                      <span className="pt-1 text-sm font-medium text-white/90">
                        {bullet.text}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
              <div className={flip ? "md:order-1" : undefined}>
                <FeatureVideo
                  mp4={`/videos/schematic-${feature.video}.mp4`}
                  webm={`/videos/schematic-${feature.video}.webm`}
                  poster={`/videos/schematic-${feature.video}.png`}
                  label={`Animated schematic of the ${feature.eyebrow} feature`}
                />
              </div>
            </div>
          </div>
        );
      })}
    </section>
  );
}
