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
    </div>
  );
}
