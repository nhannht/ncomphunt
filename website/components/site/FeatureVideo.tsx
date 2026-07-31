"use client";

import { useEffect, useRef } from "react";

/**
 * Self-hosted schematic loop: autoplaying, muted, no chrome. A single
 * mount-time play() is not reliable - React omits the `muted` attribute from
 * server HTML, so the browser's autoplay policy can reject the first attempt,
 * and some browsers refuse until the video is on screen or the user has
 * interacted. So: force the muted property, then (re)try on mount, on entering
 * the viewport, and on the first gesture. Viewers with prefers-reduced-motion
 * get the first frame as a still instead.
 */
export default function FeatureVideo({
  mp4,
  webm,
  poster,
  label,
  className = "",
}: {
  mp4: string;
  webm?: string;
  poster?: string;
  label: string;
  className?: string;
}) {
  const ref = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const video = ref.current;
    if (!video) return;
    video.muted = true;
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)");
    let inView = false;

    const tryPlay = () => {
      if (reduce.matches) {
        video.pause();
        video.currentTime = 0;
      } else if (inView && video.paused) {
        void video.play().catch(() => {});
      }
    };

    const io = new IntersectionObserver(
      entries => {
        inView = entries.some(entry => entry.isIntersecting);
        if (inView) tryPlay();
        else video.pause();
      },
      { threshold: 0.1 }
    );
    io.observe(video);

    const onGesture = () => tryPlay();
    window.addEventListener("pointerdown", onGesture, { passive: true });
    window.addEventListener("scroll", onGesture, { passive: true });
    reduce.addEventListener("change", tryPlay);

    return () => {
      io.disconnect();
      window.removeEventListener("pointerdown", onGesture);
      window.removeEventListener("scroll", onGesture);
      reduce.removeEventListener("change", tryPlay);
    };
  }, []);

  return (
    <video
      ref={ref}
      autoPlay
      muted
      loop
      playsInline
      preload="metadata"
      poster={poster}
      aria-label={label}
      className={`w-full rounded-3xl ring-1 ring-white/10 shadow-[0_24px_80px_rgba(0,0,0,0.55)] ${className}`}
    >
      <source src={mp4} type="video/mp4" />
      {webm ? <source src={webm} type="video/webm" /> : null}
    </video>
  );
}
