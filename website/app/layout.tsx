import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import Background from "@/components/site/Background";
import { site } from "@/lib/site";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: {
    default: `${site.name} - ${site.tagline}`,
    template: `%s | ${site.name}`,
  },
  description: site.description,
  keywords: [
    "hackathon",
    "ctf",
    "competitive programming",
    "coding contest",
    "ai challenge",
    "machine learning competition",
    "design contest",
    "vietnam",
    "macos app",
    "menu bar app",
  ],
  authors: [{ name: site.author, url: site.github }],
  creator: site.author,
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    url: site.url,
    siteName: site.name,
    title: `${site.name} - ${site.tagline}`,
    description: site.description,
    images: [
      {
        url: "/screenshots/as1-hero.png",
        width: 2880,
        height: 1800,
        alt: "nCompHunt main window on a MacBook, listing upcoming competitions",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: `${site.name} - ${site.tagline}`,
    description: site.description,
    images: ["/screenshots/as1-hero.png"],
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  themeColor: "#0b0e1c",
  colorScheme: "dark",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`dark ${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col overflow-x-hidden bg-background text-foreground">
        <Background />
        {children}
      </body>
    </html>
  );
}
