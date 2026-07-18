"use client";

import CardSwap, { Card } from "@/components/CardSwap";

const cardChrome =
  "!rounded-2xl !border-white/15 !bg-[#0e1226] flex flex-col overflow-hidden shadow-[0_24px_80px_rgba(0,0,0,0.55)]";

function CardHeader({ title }: { title: string }) {
  return (
    <div className="flex items-center gap-2 border-b border-white/10 bg-white/[0.04] px-4 py-3">
      <span className="size-2.5 rounded-full bg-[#FF5F57]" />
      <span className="size-2.5 rounded-full bg-[#FEBC2E]" />
      <span className="size-2.5 rounded-full bg-[#28C840]" />
      <span className="ml-2 text-sm text-white/70">{title}</span>
    </div>
  );
}

export default function Surfaces() {
  return (
    <section className="mx-auto max-w-6xl overflow-hidden px-6 py-24 md:overflow-visible">
      <div className="grid items-center gap-12 md:grid-cols-2">
        <div>
          <p className="text-sm font-medium uppercase tracking-[0.2em] text-white/40">
            Everywhere you look
          </p>
          <h2 className="mt-3 text-3xl font-semibold tracking-tight text-white [text-wrap:balance] md:text-5xl">
            One app, every surface of macOS.
          </h2>
          <p className="mt-5 max-w-md leading-relaxed text-white/60">
            The main window is for triage. The menu bar is for glancing. The
            right-click menu is for acting - open the page, add to calendar,
            share, or file it into YouTrack. Settings is where you tune the
            sources. nCompHunt meets you on whichever surface you already have
            open.
          </p>
        </div>

        <div className="relative h-[420px]">
          <CardSwap
            width={520}
            height={400}
            cardDistance={58}
            verticalDistance={68}
            delay={5000}
            skewAmount={5}
            easing="elastic"
            pauseOnHover
          >
            <Card className={cardChrome}>
              <CardHeader title="Menu bar" />
              <div className="min-h-0 flex-1">
                <img
                  src="/screenshots/menubar.png"
                  alt="nCompHunt menu bar extra listing upcoming deadlines"
                  draggable={false}
                  className="size-full select-none object-cover object-top"
                />
              </div>
            </Card>
            <Card className={cardChrome}>
              <CardHeader title="Right-click" />
              <div className="flex min-h-0 flex-1 items-center justify-center bg-[radial-gradient(70%_70%_at_50%_40%,rgba(53,116,240,0.18),transparent_75%)] p-6">
                <img
                  src="/screenshots/rightclickmenu.png"
                  alt="nCompHunt context menu with open, share, calendar, and YouTrack actions"
                  draggable={false}
                  className="max-h-full select-none rounded-lg shadow-2xl"
                />
              </div>
            </Card>
            <Card className={cardChrome}>
              <CardHeader title="Settings" />
              <div className="min-h-0 flex-1">
                <img
                  src="/screenshots/settings.png"
                  alt="nCompHunt settings window with per-source switches"
                  draggable={false}
                  className="size-full select-none object-cover object-top"
                />
              </div>
            </Card>
          </CardSwap>
        </div>
      </div>
    </section>
  );
}
