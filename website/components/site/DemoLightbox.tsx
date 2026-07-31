"use client";

import { useCallback, useEffect, useState } from "react";
import { Play, X } from "lucide-react";

/**
 * CleanShot-style demo embed: the hero screenshot doubles as the poster and a
 * click opens a full-screen lightbox with the YouTube player. The iframe is
 * not mounted until the click, so the page loads zero YouTube script; the
 * youtube-nocookie domain keeps tracking out of the pre-click page entirely.
 * Sound is allowed because the click is a user gesture, delegated to the
 * iframe via allow="autoplay".
 */
export default function DemoLightbox({
  youtubeId,
  label,
  duration,
  aspect = "1484 / 1080",
  children,
}: {
  youtubeId: string;
  label: string;
  duration?: string;
  /** CSS aspect-ratio of the source video, so the player gets no black bars. */
  aspect?: string;
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(false);
  const close = useCallback(() => setOpen(false), []);

  useEffect(() => {
    if (!open) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") close();
    };
    window.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [open, close]);

  return (
    <>
      <div className="group relative">
        {children}
        <button
          type="button"
          aria-label={label}
          onClick={() => setOpen(true)}
          className="absolute inset-0 flex cursor-pointer flex-col items-center justify-center gap-4"
        >
          {/* Dark glass, not white: the poster is the app's light-mode
              screenshot, so a white circle disappears into it. */}
          <span className="flex size-16 items-center justify-center rounded-full bg-black/65 text-white ring-1 ring-white/40 backdrop-blur-md shadow-[0_16px_48px_rgba(0,0,0,0.55)] transition-transform duration-200 group-hover:scale-110">
            <Play className="ml-1 size-7 fill-current" />
          </span>
          {duration ? (
            <span className="rounded-full bg-black/65 px-4 py-1.5 text-sm text-white ring-1 ring-white/25 backdrop-blur-md opacity-0 transition-opacity duration-200 group-hover:opacity-100">
              Watch with sound ({duration})
            </span>
          ) : null}
        </button>
      </div>

      {open ? (
        <div
          role="dialog"
          aria-modal="true"
          aria-label={label}
          onClick={close}
          className="fixed inset-0 z-[100] flex items-center justify-center bg-black/85 p-4 backdrop-blur-md sm:p-8"
        >
          <button
            type="button"
            aria-label="Close video"
            onClick={close}
            className="absolute right-4 top-4 rounded-full bg-white/10 p-2.5 text-white transition-colors hover:bg-white/25"
          >
            <X className="size-6" />
          </button>
          <div
            onClick={event => event.stopPropagation()}
            style={{ aspectRatio: aspect }}
            className="max-h-[85vh] w-[min(1200px,92vw)] overflow-hidden rounded-2xl ring-1 ring-white/15 shadow-[0_40px_120px_rgba(0,0,0,0.8)]"
          >
            <iframe
              src={`https://www.youtube-nocookie.com/embed/${youtubeId}?autoplay=1&rel=0&playsinline=1`}
              title={label}
              allow="autoplay; encrypted-media; fullscreen; picture-in-picture"
              allowFullScreen
              className="size-full border-0"
            />
          </div>
        </div>
      ) : null}
    </>
  );
}
