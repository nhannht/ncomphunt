"use client";

import { Globe, Image as ImageIcon, LayoutGrid, Sparkles } from "lucide-react";
import Dock, { type DockItemData } from "@/components/Dock";
import { site } from "@/lib/site";
import { GitHubIcon } from "./icons";

function scrollTo(id: string) {
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
}

const items: DockItemData[] = [
  {
    icon: <Sparkles className="size-5 text-white" />,
    label: "Overview",
    onClick: () => scrollTo("top"),
  },
  {
    icon: <LayoutGrid className="size-5 text-white" />,
    label: "Features",
    onClick: () => scrollTo("features"),
  },
  {
    icon: <Globe className="size-5 text-white" />,
    label: "Sources",
    onClick: () => scrollTo("sources"),
  },
  {
    icon: <ImageIcon className="size-5 text-white" />,
    label: "Screenshots",
    onClick: () => scrollTo("screenshots"),
  },
  {
    icon: <GitHubIcon className="size-5 text-white" />,
    label: "GitHub",
    onClick: () => window.open(site.github, "_blank", "noreferrer"),
  },
];

export default function DockBar() {
  return (
    <div className="pointer-events-none fixed inset-x-0 bottom-0 z-50 hidden justify-center md:flex">
      <div className="pointer-events-auto">
        <Dock items={items} panelHeight={64} baseItemSize={46} magnification={66} />
      </div>
    </div>
  );
}
