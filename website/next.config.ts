import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Static export: the whole site prerenders, GitHub Pages serves ./out.
  output: "export",
  // No image-optimizer server in a static export.
  images: { unoptimized: true },
};

export default nextConfig;
