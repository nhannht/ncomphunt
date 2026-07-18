"use client";

import Image from "next/image";
import Link from "next/link";
import GlassSurface from "@/components/GlassSurface";
import GooeyNav from "@/components/GooeyNav";
import { site } from "@/lib/site";
import { GitHubIcon } from "./icons";

const links = [
  { href: "#features", label: "Features" },
  { href: "#sources", label: "Sources" },
  { href: "#screenshots", label: "Screenshots" },
  { href: "#open-source", label: "Open Source" },
];

export default function NavBar() {
  return (
    <header className="fixed inset-x-0 top-0 z-50 px-4 pt-4">
      <div className="mx-auto max-w-5xl">
        <GlassSurface
          width="100%"
          height={56}
          borderRadius={28}
          backgroundOpacity={0.45}
          blur={18}
          distortionScale={-60}
          redOffset={0}
          greenOffset={4}
          blueOffset={8}
        >
          <div className="flex w-full items-center justify-between px-3 sm:px-5">
            <Link href="#top" className="flex items-center gap-2.5">
              <Image
                src="/app-icon.png"
                alt=""
                width={30}
                height={30}
                className="rounded-[8px]"
                priority
              />
              <span className="text-[15px] font-semibold tracking-tight text-white">
                {site.name}
              </span>
            </Link>

            <div className="hidden text-sm md:block">
              <GooeyNav
                items={links.map(link => ({ label: link.label, href: link.href }))}
                particleCount={12}
                particleDistances={[70, 10]}
                animationTime={500}
              />
            </div>

            <div className="flex items-center gap-3">
              <a
                href={site.github}
                target="_blank"
                rel="noreferrer"
                aria-label="nCompHunt on GitHub"
                className="text-white/70 transition-colors hover:text-white"
              >
                <GitHubIcon className="size-5" />
              </a>
              <a
                href="#download"
                className="rounded-full bg-white px-4 py-1.5 text-sm font-medium text-black transition-opacity hover:opacity-85"
              >
                Get the app
              </a>
            </div>
          </div>
        </GlassSurface>
      </div>
    </header>
  );
}
