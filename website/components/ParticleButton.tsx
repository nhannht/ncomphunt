"use client";

import { useRef, type CSSProperties, type ReactNode } from "react";
import { makeParticles } from "@/lib/particles";

type ParticleButtonProps = {
  children: ReactNode;
  /** Renders an anchor instead of a button. */
  href?: string;
  /** Opens the href in a new tab. Ignored without href. */
  external?: boolean;
  onClick?: () => void;
  /** Colors the resting edge. Defaults to a plain white edge. */
  accent?: string;
  /** Color the pill fills with on hover. Defaults to white, matching the nav's
   *  active item. Override where a white fill would collide with a white
   *  neighbour. */
  fill?: string;
  /** Label color once the pill has filled. Defaults to black. */
  ink?: string;
  className?: string;
  "aria-label"?: string;
};

export default function ParticleButton({
  children,
  href,
  external = false,
  onClick,
  accent,
  fill,
  ink,
  className = "",
  "aria-label": ariaLabel,
}: ParticleButtonProps) {
  const burstRef = useRef<HTMLSpanElement>(null);

  const burst = () => {
    const host = burstRef.current;
    if (!host) return;
    host.querySelectorAll(".particle").forEach(node => node.remove());
    makeParticles(host, {
      particleCount: 12,
      particleDistances: [76, 10],
      particleR: 90,
      animationTime: 460,
      timeVariance: 240,
    });
  };

  const style = {
    ...(accent ? { "--mbtn-edge": accent } : {}),
    ...(fill ? { "--mbtn-fill": fill } : {}),
    ...(ink ? { "--mbtn-ink": ink } : {}),
  } as CSSProperties;

  const inner = (
    <>
      <span className="mbtn-burst" ref={burstRef} aria-hidden="true" />
      <span className="mbtn-label">{children}</span>
    </>
  );

  const classes = `mbtn ${className}`.trim();

  if (href) {
    return (
      <a
        href={href}
        style={style}
        className={classes}
        aria-label={ariaLabel}
        onClick={burst}
        {...(external ? { target: "_blank", rel: "noreferrer" } : {})}
      >
        {inner}
      </a>
    );
  }

  return (
    <button
      type="button"
      style={style}
      className={classes}
      aria-label={ariaLabel}
      onClick={() => {
        burst();
        onClick?.();
      }}
    >
      {inner}
    </button>
  );
}
