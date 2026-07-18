"use client";

import { useEffect, useState } from "react";
import Carousel, { type CarouselItem } from "@/components/Carousel";

const shots: CarouselItem[] = [
  {
    id: 1,
    title: "The main window",
    description: "Filters, list, and detail in one native split view.",
    image: "/screenshots/as1-hero.png",
  },
  {
    id: 2,
    title: "The menu bar extra",
    description: "The next deadlines, one click away.",
    image: "/screenshots/as2-menubar.png",
  },
  {
    id: 3,
    title: "Per-source switches",
    description: "Everything on, or exactly what you want.",
    image: "/screenshots/as3-sources.png",
  },
  {
    id: 4,
    title: "Right-click actions",
    description: "Open, share, calendar, or file to YouTrack.",
    image: "/screenshots/as4-actions.png",
  },
  {
    id: 5,
    title: "Sort, group, filter",
    description: "Sort by deadline, group by category, filter by region.",
    image: "/screenshots/as5-widget.png",
  },
];

export default function Gallery() {
  const [baseWidth, setBaseWidth] = useState(960);

  useEffect(() => {
    const measure = () =>
      setBaseWidth(Math.min(960, window.innerWidth - 32));
    measure();
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, []);

  return (
    <section id="screenshots" className="scroll-mt-24 py-24">
      <div className="mx-auto max-w-6xl px-6">
        <p className="text-sm font-medium uppercase tracking-[0.2em] text-white/40">
          Screenshots
        </p>
        <h2 className="mt-3 max-w-2xl text-3xl font-semibold tracking-tight text-white [text-wrap:balance] md:text-5xl">
          Have a look around.
        </h2>
        <p className="mt-4 max-w-xl text-white/50">
          Drag, or let it drift. It loops.
        </p>
      </div>

      <div className="mt-12 flex justify-center px-4">
        <Carousel
          items={shots}
          baseWidth={baseWidth}
          autoplay
          autoplayDelay={4500}
          pauseOnHover
          loop
        />
      </div>
    </section>
  );
}
