// The gooey particle burst, shared by GooeyNav and ParticleButton so the nav
// and the buttons animate with one motion language. Lifted verbatim out of the
// react-bits GooeyNav component; the matching CSS (.particle, .point, and the
// two keyframes) lives in globals.css.

export type ParticleOptions = {
  particleCount?: number;
  particleDistances?: [number, number];
  particleR?: number;
  animationTime?: number;
  timeVariance?: number;
  colors?: number[];
};

const noise = (n = 1) => n / 2 - Math.random() * n;

function getXY(
  distance: number,
  pointIndex: number,
  totalPoints: number,
): [number, number] {
  const angle = ((360 + noise(8)) / totalPoints) * pointIndex * (Math.PI / 180);
  return [distance * Math.cos(angle), distance * Math.sin(angle)];
}

function createParticle(
  i: number,
  t: number,
  d: [number, number],
  r: number,
  particleCount: number,
  colors: number[],
) {
  const rotate = noise(r / 10);
  return {
    start: getXY(d[0], particleCount - i, particleCount),
    end: getXY(d[1] + noise(7), particleCount - i, particleCount),
    time: t,
    scale: 1 + noise(0.2),
    color: colors[Math.floor(Math.random() * colors.length)],
    rotate: rotate > 0 ? (rotate + r / 20) * 10 : (rotate - r / 20) * 10,
  };
}

/** Spawns one burst of particles inside `element`, cleaning each up on its own
 *  timer. `element` must be positioned and unclipped - the particles travel
 *  outside its box. */
export function makeParticles(
  element: HTMLElement,
  {
    particleCount = 15,
    particleDistances = [90, 10],
    particleR = 100,
    animationTime = 600,
    timeVariance = 300,
    colors = [1, 2, 3, 1, 2, 3, 1, 4],
  }: ParticleOptions = {},
) {
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

  const bubbleTime = animationTime * 2 + timeVariance;
  element.style.setProperty("--time", `${bubbleTime}ms`);

  for (let i = 0; i < particleCount; i++) {
    const t = animationTime * 2 + noise(timeVariance * 2);
    const p = createParticle(i, t, particleDistances, particleR, particleCount, colors);
    element.classList.remove("active");

    setTimeout(() => {
      const particle = document.createElement("span");
      const point = document.createElement("span");
      particle.classList.add("particle");
      particle.style.setProperty("--start-x", `${p.start[0]}px`);
      particle.style.setProperty("--start-y", `${p.start[1]}px`);
      particle.style.setProperty("--end-x", `${p.end[0]}px`);
      particle.style.setProperty("--end-y", `${p.end[1]}px`);
      particle.style.setProperty("--time", `${p.time}ms`);
      particle.style.setProperty("--scale", `${p.scale}`);
      particle.style.setProperty("--color", `var(--color-${p.color}, white)`);
      particle.style.setProperty("--rotate", `${p.rotate}deg`);
      point.classList.add("point");
      particle.appendChild(point);
      element.appendChild(particle);
      requestAnimationFrame(() => {
        element.classList.add("active");
      });
      setTimeout(() => {
        try {
          element.removeChild(particle);
        } catch {}
      }, t);
    }, 30);
  }
}
