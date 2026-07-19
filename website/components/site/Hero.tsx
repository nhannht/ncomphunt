"use client";

import Image from "next/image";
import SpecularButton from "@/components/SpecularButton";
import SplitText from "@/components/SplitText";
import ShinyText from "@/components/ShinyText";
import { brand, site } from "@/lib/site";
import { AppleIcon, GitHubIcon } from "./icons";

const categories = [
  { label: "Competitive Programming", color: brand.blue },
  { label: "CTF", color: brand.pink },
  { label: "AI / ML", color: "#F59E0B" },
  { label: "Hackathon", color: "#22D3EE" },
  { label: "Design", color: "#F472B6" },
  { label: "Other", color: "#94A3B8" },
];

export default function Hero() {
  return (
    <section id="top" className="relative overflow-hidden">
      <div className="relative mx-auto flex max-w-5xl flex-col items-center px-6 pb-24 pt-40 text-center">
        <div className="glass rounded-full px-4 py-1.5">
          <ShinyText
            text="Free and open source. MIT licensed."
            speed={3}
            color="#c8cdda"
            className="text-sm"
          />
        </div>

        <SplitText
          tag="h1"
          text="Every competition, one native Mac app."
          splitType="words"
          delay={80}
          duration={1.2}
          from={{ opacity: 0, y: 48 }}
          to={{ opacity: 1, y: 0 }}
          className="mt-8 max-w-4xl text-5xl font-semibold tracking-tight text-white [text-wrap:balance] sm:text-6xl md:text-7xl"
        />

        <p className="mt-6 max-w-2xl text-lg text-white/70 md:text-xl">
          Competitive programming rounds, AI challenges, CTFs, hackathons, and
          design contests - found, sorted, and waiting in your menu bar.
          Vietnam-first, global always.
        </p>

        <div id="download" className="mt-10 flex flex-wrap items-center justify-center gap-4">
          <a
            href={site.downloadUrl}
            className="inline-flex items-center gap-3 rounded-2xl bg-white px-6 py-3 text-black transition-opacity hover:opacity-85"
          >
            <AppleIcon className="size-7" />
            <span className="text-left leading-tight">
              <span className="block text-[11px] font-medium uppercase tracking-wide text-black/60">
                Signed and notarized
              </span>
              <span className="block text-lg font-semibold">Download for Mac</span>
            </span>
          </a>

          <SpecularButton
            size="lg"
            radius={16}
            tint="#ffffff"
            tintOpacity={0.06}
            blur={14}
            lineColor="#ffffff"
            baseColor="#7a86b8"
            intensity={1.1}
            autoAnimate
            onClick={() => window.open(site.github, "_blank", "noreferrer")}
          >
            <span className="flex items-center gap-3">
              <GitHubIcon className="size-6" />
              <span className="text-[15px] font-medium">View on GitHub</span>
            </span>
          </SpecularButton>
        </div>

        <code className="glass mt-5 rounded-full px-4 py-1.5 text-sm text-white/70">
          {site.brew}
        </code>

        <p className="mt-4 text-sm text-white/40">
          {site.requirement} - signed with Developer ID, notarized by Apple
        </p>

        <div className="mt-10 flex flex-wrap items-center justify-center gap-2">
          {categories.map(category => (
            <span
              key={category.label}
              className="glass flex items-center gap-2 rounded-full px-3.5 py-1.5 text-sm text-white/80"
            >
              <span
                className="size-2 rounded-full"
                style={{ backgroundColor: category.color }}
              />
              {category.label}
            </span>
          ))}
        </div>

        <div className="relative mt-16 w-full">
          <div className="pointer-events-none absolute -inset-x-10 -top-12 bottom-0 bg-[radial-gradient(60%_60%_at_50%_40%,rgba(216,37,252,0.18),transparent_70%)]" />
          <Image
            src="/screenshots/main-window.png"
            alt="nCompHunt main window: sidebar with category filters, competition list, and a CTF detail pane"
            width={2560}
            height={1664}
            priority
            className="relative w-full drop-shadow-[0_40px_80px_rgba(0,0,0,0.6)]"
          />
        </div>
      </div>
    </section>
  );
}
