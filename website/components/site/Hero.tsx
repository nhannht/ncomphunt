"use client";

import DemoLightbox from "@/components/site/DemoLightbox";
import FeatureVideo from "@/components/site/FeatureVideo";
import ParticleButton from "@/components/ParticleButton";
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
      <div className="relative mx-auto max-w-6xl px-6 pb-16 pt-32 md:pt-36">
        {/* CleanShot-style split hero: pitch and buttons left, a compact
            muted preview loop right that opens the full demo with sound. */}
        <div className="grid items-center gap-10 md:grid-cols-2 md:gap-14">
          <div className="flex flex-col items-center text-center md:items-start md:text-left">
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
              className="mt-6 text-4xl font-semibold tracking-tight text-white [text-wrap:balance] sm:text-5xl lg:text-6xl"
            />

            <p className="mt-5 max-w-xl text-lg text-white/85">
              Competitive programming rounds, AI challenges, CTFs, hackathons,
              and design contests - found, sorted, and waiting in your menu
              bar. Vietnam-first, global always.
            </p>

            <div
              id="download"
              className="mt-8 flex flex-wrap items-center justify-center gap-4 md:justify-start"
            >
              <a
                href={site.downloadUrl}
                className="inline-flex items-center gap-3 rounded-2xl bg-white px-6 py-3 text-black transition-opacity hover:opacity-85"
              >
                <AppleIcon className="size-7" />
                <span className="text-left leading-tight">
                  <span className="block text-[11px] font-medium uppercase tracking-wide text-black/60">
                    Signed and notarized
                  </span>
                  <span className="block text-lg font-semibold">
                    Download for Mac
                  </span>
                </span>
              </a>

              {/* Height-matched to the Download button beside it (two-line label).
                  Fills brand blue rather than the default white, which would read as
                  a second copy of the white primary sitting right next to it. */}
              <ParticleButton
                href={site.github}
                external
                fill="#2f68e0"
                ink="#ffffff"
                className="!h-[66px] !px-6"
              >
                <GitHubIcon className="size-6" />
                View on GitHub
              </ParticleButton>
            </div>

            <code className="glass mt-5 rounded-full px-4 py-1.5 text-sm text-white/90">
              {site.brew}
            </code>

            <p className="mt-3 text-sm text-white/70">
              {site.requirement} - signed with Developer ID, notarized by Apple
            </p>
          </div>

          <div className="relative">
            <div className="pointer-events-none absolute -inset-x-12 -inset-y-10 bg-[radial-gradient(60%_60%_at_50%_50%,rgba(216,37,252,0.18),transparent_70%)]" />
            <DemoLightbox
              youtubeId="pWfu7XGXa3Y"
              label="Play the nCompHunt demo video"
              duration="80 sec"
            >
              <FeatureVideo
                mp4="/videos/hero-preview.mp4"
                label="Silent preview of the nCompHunt demo"
              />
            </DemoLightbox>
          </div>
        </div>

        <div className="mt-12 flex flex-wrap items-center justify-center gap-2">
          {categories.map(category => (
            <span
              key={category.label}
              className="glass flex items-center gap-2 rounded-full px-3.5 py-1.5 text-sm text-white/90"
            >
              <span
                className="size-2 rounded-full"
                style={{ backgroundColor: category.color }}
              />
              {category.label}
            </span>
          ))}
        </div>
      </div>
    </section>
  );
}
