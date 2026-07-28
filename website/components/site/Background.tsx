"use client";

import FloatingLines from "@/components/FloatingLines";
import { brand } from "@/lib/site";

// Fixed to the viewport so the lines follow the screen through the whole
// scroll; -z-10 paints it behind every section (body background propagates
// to the canvas, so negative z still renders above it).
export default function Background() {
  return (
    <div className="pointer-events-none fixed inset-0 -z-10" aria-hidden="true">
      <FloatingLines
        linesGradient={[brand.pink, "#8A7CFF", brand.blue]}
        enabledWaves={["top", "middle", "bottom"]}
        lineCount={[5, 7, 5]}
        lineDistance={[6, 5, 6]}
        animationSpeed={0.8}
        interactive
        parallax
        parallaxStrength={0.25}
      />
      {/* Scrim. The waves are ambient light, not a competitor to the copy on
          top of them: at full brightness a white streak lands under a
          paragraph and drops it to ~3:1. The flat pass cuts peak luminance,
          the radial pass darkens the edges where headings start. */}
      <div className="absolute inset-0 bg-[#0b0e1c]/60" />
      <div className="absolute inset-0 bg-[radial-gradient(115%_75%_at_50%_35%,transparent_0%,rgba(11,14,28,0.55)_100%)]" />
    </div>
  );
}
