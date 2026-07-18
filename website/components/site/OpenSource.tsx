"use client";

import GradientText from "@/components/GradientText";
import ShinyText from "@/components/ShinyText";
import SpecularButton from "@/components/SpecularButton";
import { brand, site } from "@/lib/site";
import { GitHubIcon } from "./icons";

export default function OpenSource() {
  return (
    <section id="open-source" className="mx-auto max-w-5xl scroll-mt-24 px-6 py-24">
      <div className="glass flex flex-col items-center rounded-[2.5rem] px-8 py-16 text-center md:px-16">
        <GradientText
          colors={[brand.pink, "#8A7CFF", brand.blue]}
          animationSpeed={6}
          className="text-3xl font-semibold tracking-tight [text-wrap:balance] md:text-5xl"
        >
          No account. No telemetry. No server.
        </GradientText>

        <p className="mt-6 max-w-2xl text-white/60">
          The app fetches listings directly from the sources, and the index it
          builds never leaves your Mac. There is nothing between you and the
          contests - not even us. The entire codebase is public, so you do not
          have to take our word for it.
        </p>

        <div className="mt-8">
          <ShinyText
            text="MIT licensed. Free forever."
            speed={3}
            color="#c8cdda"
            className="text-lg font-medium"
          />
        </div>

        <div className="mt-8 flex flex-wrap items-center justify-center gap-4">
          <SpecularButton
            size="md"
            radius={16}
            tint="#ffffff"
            tintOpacity={0.08}
            blur={14}
            lineColor="#ffffff"
            baseColor="#8b95c9"
            intensity={1.1}
            autoAnimate
            onClick={() => window.open(site.github, "_blank", "noreferrer")}
          >
            <span className="flex items-center gap-3">
              <GitHubIcon className="size-5" />
              <span className="font-medium">Read the source</span>
            </span>
          </SpecularButton>
          <SpecularButton
            size="md"
            radius={16}
            tint={brand.pink}
            tintOpacity={0.08}
            blur={14}
            lineColor={brand.pink}
            baseColor="#6b4d8a"
            intensity={1.2}
            autoAnimate
            onClick={() => window.open(site.issues, "_blank", "noreferrer")}
          >
            <span className="font-medium">Report an issue</span>
          </SpecularButton>
        </div>
      </div>
    </section>
  );
}
