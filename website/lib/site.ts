export const site = {
  name: "nCompHunt",
  tagline: "Every competition, one native Mac app",
  description:
    "Competitive programming, AI challenges, CTFs, hackathons, and design contests - found, sorted, and waiting in your menu bar. No account, no server, all on your Mac.",
  url: process.env.NEXT_PUBLIC_SITE_URL ?? "https://ncomphunt.nhannht.io.vn",
  github: "https://github.com/nhannht/ncomphunt",
  issues: "https://github.com/nhannht/ncomphunt/issues",
  privacy: "/privacy",
  // Fill in the App Store link once the listing is live.
  appStoreUrl: "",
  requirement: "Requires macOS 15 or later",
  author: "Nguyen Huu Thien Nhan",
} as const;

export const brand = {
  pink: "#D825FC",
  navy: "#1C3D7A",
  blue: "#3574F0",
} as const;
