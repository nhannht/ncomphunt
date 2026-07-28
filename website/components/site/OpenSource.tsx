"use client";

import GradientText from "@/components/GradientText";
import ParticleButton from "@/components/ParticleButton";
import ShinyText from "@/components/ShinyText";
import { brand, site } from "@/lib/site";
import { GitHubIcon } from "./icons";

export default function OpenSource() {
  return (
    <section id="open-source" className="mx-auto max-w-5xl scroll-mt-24 px-6 py-24">
      <div className="paper flex flex-col items-center rounded-[2.5rem] px-8 py-16 text-center md:px-16">
        <GradientText
          colors={[brand.pink, "#8A7CFF", brand.blue]}
          animationSpeed={6}
          className="text-3xl font-semibold tracking-tight [text-wrap:balance] md:text-5xl"
        >
          Open source, top to bottom.
        </GradientText>

        <p className="mt-6 max-w-2xl text-white/85">
          The app fetches listings straight from the sources and keeps its index
          on your Mac. It works with no account and no setup. The entire
          codebase is public, so you do not have to take our word for any of
          it - read it, build it, change it.
        </p>

        <div className="mt-8">
          <ShinyText
            text="MIT licensed. Free to download and use."
            speed={3}
            color="#dfe3ee"
            className="text-lg font-medium"
          />
        </div>

        <div className="mt-8 flex flex-wrap items-center justify-center gap-4">
          <ParticleButton href={site.github} external>
            <GitHubIcon className="size-5" />
            Read the source
          </ParticleButton>
          <ParticleButton
            href={site.issues}
            external
            accent="rgba(216, 37, 252, 0.55)"
          >
            Report an issue
          </ParticleButton>
        </div>
      </div>
    </section>
  );
}
