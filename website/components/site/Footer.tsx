import Image from "next/image";
import { site } from "@/lib/site";

export default function Footer() {
  return (
    <footer className="border-t border-white/10">
      <div className="mx-auto flex max-w-6xl flex-col gap-6 px-6 py-10 pb-28 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-3">
          <Image
            src="/app-icon.png"
            alt=""
            width={28}
            height={28}
            className="rounded-[7px]"
          />
          <div>
            <p className="text-sm font-medium text-white">{site.name}</p>
            <p className="text-xs text-white/40">
              (c) 2026 {site.author}. MIT License. {site.requirement}.
            </p>
          </div>
        </div>

        <nav className="flex flex-wrap gap-x-6 gap-y-2 text-sm text-white/60">
          <a
            href={site.github}
            target="_blank"
            rel="noreferrer"
            className="transition-colors hover:text-white"
          >
            GitHub
          </a>
          <a
            href={site.issues}
            target="_blank"
            rel="noreferrer"
            className="transition-colors hover:text-white"
          >
            Support
          </a>
          <a
            href={site.privacy}
            className="transition-colors hover:text-white"
          >
            Privacy
          </a>
        </nav>
      </div>
    </footer>
  );
}
