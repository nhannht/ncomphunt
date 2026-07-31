"use client";

import {
  Database,
  KeyRound,
  Laptop,
  Scale,
  ShieldCheck,
  SquareKanban,
} from "lucide-react";
import SpotlightCard from "@/components/SpotlightCard";

const items = [
  {
    icon: Laptop,
    title: "Native SwiftUI",
    body: "Swift 6, SwiftData, a real Mac window. Not a wrapped web page.",
  },
  {
    icon: ShieldCheck,
    title: "Sandboxed and notarized",
    body: "Every build is sandboxed, signed with a Developer ID, and notarized by Apple.",
  },
  {
    icon: Database,
    title: "No account, no cloud",
    body: "The index lives in local storage on your Mac. There is nothing to sign in to.",
  },
  {
    icon: KeyRound,
    title: "Keys in the Keychain",
    body: "Optional API keys are stored in the macOS Keychain and sent only to their own service.",
  },
  {
    icon: SquareKanban,
    title: "YouTrack filing",
    body: "Decided to enter? One action files the contest as an issue in your YouTrack.",
  },
  {
    icon: Scale,
    title: "MIT licensed",
    body: "Free and open source. Read the code, build it yourself, or just use it.",
  },
];

export default function SmallFeatures() {
  return (
    <section className="relative mx-auto max-w-6xl px-6 py-24">
      <p className="text-sm font-medium uppercase tracking-[0.2em] text-white/70">
        Details
      </p>
      <h2 className="mt-3 max-w-2xl text-3xl font-semibold tracking-tight text-white [text-wrap:balance] md:text-5xl">
        And the parts you only notice later.
      </h2>

      <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {items.map(item => (
          <SpotlightCard
            key={item.title}
            className="paper"
            spotlightColor="rgba(216, 37, 252, 0.16)"
          >
            <div className="flex size-11 items-center justify-center rounded-xl bg-gradient-to-br from-[#D825FC] to-[#3574F0]">
              <item.icon className="size-5 text-white" />
            </div>
            <h3 className="mt-5 text-lg font-semibold text-white">{item.title}</h3>
            <p className="mt-2 text-sm leading-relaxed text-white/85">{item.body}</p>
          </SpotlightCard>
        ))}
      </div>
    </section>
  );
}
