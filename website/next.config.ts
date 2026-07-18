import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Static export: the whole site prerenders, nginx serves ./out directly.
  output: "export",
  // No image-optimizer server in a static export.
  images: { unoptimized: true },
};

export default nextConfig;
