"use client";

import GradientText from "@/components/GradientText";
import { brand } from "@/lib/site";

const vnBrands = ["VNOI", "WhiteHat", "Zalo", "SVATTT", "ybox.vn"];

export default function Vietnam() {
  return (
    <section className="mx-auto max-w-6xl px-6 py-24">
      <div className="glass grid gap-10 rounded-[2.5rem] p-10 md:grid-cols-2 md:p-14">
        <div>
          <GradientText
            colors={[brand.pink, "#8A7CFF", brand.blue]}
            animationSpeed={6}
            className="!mx-0 text-3xl font-semibold tracking-tight md:text-4xl"
          >
            Vietnam-first. Global always.
          </GradientText>
          <p className="mt-5 leading-relaxed text-white/60">
            ybox.vn brings the Vietnamese design, scholarship, and
            general-interest lane. On top of that, nCompHunt recognizes
            Vietnamese technical contests even when they arrive from global
            aggregators under an English title and a non-.vn host - so the
            Vietnam filter actually means something.
          </p>
        </div>
        <div className="flex flex-col justify-center">
          <p className="text-sm font-medium uppercase tracking-[0.2em] text-white/40">
            Recognized brands
          </p>
          <div className="mt-4 flex flex-wrap gap-2">
            {vnBrands.map(name => (
              <span
                key={name}
                className="glass rounded-full px-4 py-2 text-sm font-medium text-white/85"
              >
                {name}
              </span>
            ))}
          </div>
          <p className="mt-5 text-sm text-white/40">
            One region filter, two worlds: everything, or just what matters at
            home.
          </p>
        </div>
      </div>
    </section>
  );
}
