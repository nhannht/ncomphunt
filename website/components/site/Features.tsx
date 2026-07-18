"use client";

import {
  Bell,
  CalendarDays,
  Command,
  LayoutDashboard,
  ShieldCheck,
  SlidersHorizontal,
} from "lucide-react";
import SpotlightCard from "@/components/SpotlightCard";

const features = [
  {
    icon: Command,
    title: "Lives in your menu bar",
    body: "A menu bar extra keeps the next deadlines one click away, all day, without a window in your way.",
  },
  {
    icon: LayoutDashboard,
    title: "Widget on your desktop",
    body: "See what is coming up without opening the app. The widget stays current as contests change.",
  },
  {
    icon: Bell,
    title: "Native notifications",
    body: "Know the moment a new contest is found. Notifications are optional and requested only when you turn them on.",
  },
  {
    icon: CalendarDays,
    title: "Calendar sync",
    body: "A dedicated Apple Calendar keeps every deadline updated in place, or add a single contest as an .ics import.",
  },
  {
    icon: SlidersHorizontal,
    title: "Filter, sort, group",
    body: "Category and region filters plus sort and group controls, in a real SwiftUI window that feels at home on macOS.",
  },
  {
    icon: ShieldCheck,
    title: "Private by design",
    body: "No account, no telemetry, no analytics, no back-end server. The index nCompHunt builds never leaves your Mac.",
  },
];

export default function Features() {
  return (
    <section id="features" className="relative mx-auto max-w-6xl scroll-mt-24 px-6 py-24">
      <p className="text-sm font-medium uppercase tracking-[0.2em] text-white/40">
        Built for macOS
      </p>
      <h2 className="mt-3 max-w-2xl text-3xl font-semibold tracking-tight text-white [text-wrap:balance] md:text-5xl">
        It does not just run on your Mac. It belongs there.
      </h2>

      <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {features.map(feature => (
          <SpotlightCard
            key={feature.title}
            className="!border-white/10 !bg-white/[0.04] backdrop-blur-xl"
            spotlightColor="rgba(216, 37, 252, 0.16)"
          >
            <div className="flex size-11 items-center justify-center rounded-xl bg-gradient-to-br from-[#D825FC] to-[#3574F0]">
              <feature.icon className="size-5 text-white" />
            </div>
            <h3 className="mt-5 text-lg font-semibold text-white">
              {feature.title}
            </h3>
            <p className="mt-2 text-sm leading-relaxed text-white/60">
              {feature.body}
            </p>
          </SpotlightCard>
        ))}
      </div>
    </section>
  );
}
