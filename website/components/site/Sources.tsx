"use client";

import LogoLoop, { type LogoItem } from "@/components/LogoLoop";

// Keep fadeOutColor in sync with --background in globals.css.
const BG = "#0b0e1c";

function pill(name: string, note: string, dimmed = false): LogoItem {
  return {
    node: (
      <div
        className={`glass flex items-baseline gap-2.5 rounded-full px-5 py-2.5 ${
          dimmed ? "opacity-70" : ""
        }`}
      >
        <span className="text-[15px] font-medium text-white">{name}</span>
        <span className="text-xs text-white/50">{note}</span>
      </div>
    ),
    title: name,
    ariaLabel: `${name}: ${note}`,
  };
}

const keyless: LogoItem[] = [
  pill("CTFtime", "the worldwide CTF calendar"),
  pill("Devpost", "global hackathons"),
  pill("Codeforces", "upcoming CP rounds"),
  pill("MLContests", "open AI and ML challenges"),
  pill("ybox.vn", "Vietnamese contests"),
  pill("Contest Watchers", "creative and design"),
];

const byok: LogoItem[] = [
  pill("clist.by", "hundreds more contests", true),
  pill("Brave Search", "web discovery", true),
  pill("Google Programmable Search", "web discovery", true),
];

export default function Sources() {
  return (
    <section id="sources" className="relative scroll-mt-24 py-24">
      <div className="mx-auto max-w-6xl px-6">
        <p className="text-sm font-medium uppercase tracking-[0.2em] text-white/40">
          Sources
        </p>
        <h2 className="mt-3 max-w-2xl text-3xl font-semibold tracking-tight text-white [text-wrap:balance] md:text-5xl">
          Working the moment you open it. No setup, no account.
        </h2>
        <p className="mt-5 max-w-2xl text-white/60">
          Six sources populate the app out of the box. Every source has an
          on/off switch, and one that fails or is unconfigured is simply
          skipped - it never stops the rest of a refresh.
        </p>
      </div>

      <div className="mt-12 space-y-5">
        <LogoLoop
          logos={keyless}
          speed={70}
          direction="left"
          gap={20}
          logoHeight={44}
          pauseOnHover
          fadeOut
          fadeOutColor={BG}
          ariaLabel="Keyless sources included out of the box"
        />
        <LogoLoop
          logos={byok}
          speed={50}
          direction="right"
          gap={20}
          logoHeight={44}
          pauseOnHover
          fadeOut
          fadeOutColor={BG}
          ariaLabel="Optional sources unlocked with your own free API keys"
        />
      </div>

      <p className="mx-auto mt-10 max-w-2xl px-6 text-center text-sm text-white/40">
        The dimmed lane unlocks with your own free API keys, stored in the
        macOS Keychain and sent only to the service they belong to.
      </p>
    </section>
  );
}
