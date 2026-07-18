import fs from "node:fs";
import path from "node:path";
import type { Metadata } from "next";
import Link from "next/link";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import Footer from "@/components/site/Footer";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "nCompHunt collects nothing about you: no accounts, no analytics, no telemetry, no server. Read the full privacy policy.",
  alternates: { canonical: "/privacy" },
};

// Repo-root PRIVACY.md is the single source of truth; read it at build time.
const policy = fs.readFileSync(
  path.join(process.cwd(), "..", "PRIVACY.md"),
  "utf8",
);

export default function PrivacyPage() {
  return (
    <>
      <header className="mx-auto w-full max-w-3xl px-6 pt-8">
        <Link
          href="/"
          className="text-sm text-white/60 transition-colors hover:text-white"
        >
          &larr; Back to home
        </Link>
      </header>

      <main className="mx-auto max-w-3xl px-6 py-12">
        {/* Opaque surface: this is a document to read, the animated background
            stays in the margins only. */}
        <article className="rounded-3xl border border-white/10 bg-[#0e1226] px-6 py-10 shadow-2xl sm:px-10">
          <ReactMarkdown
            remarkPlugins={[remarkGfm]}
            components={{
              h1: ({ children }) => (
                <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
                  {children}
                </h1>
              ),
              h2: ({ children }) => (
                <h2 className="mt-10 text-xl font-semibold text-white">
                  {children}
                </h2>
              ),
              p: ({ children }) => (
                <p className="mt-4 leading-relaxed text-white/90">{children}</p>
              ),
              ul: ({ children }) => (
                <ul className="mt-4 list-disc space-y-2 pl-5 text-white/90">
                  {children}
                </ul>
              ),
              li: ({ children }) => (
                <li className="leading-relaxed">{children}</li>
              ),
              a: ({ href, children }) => (
                <a
                  href={href}
                  target="_blank"
                  rel="noreferrer"
                  className="text-white underline decoration-white/30 underline-offset-4 transition-colors hover:decoration-white"
                >
                  {children}
                </a>
              ),
              strong: ({ children }) => (
                <strong className="font-semibold text-white">{children}</strong>
              ),
            }}
          >
            {policy}
          </ReactMarkdown>
        </article>
      </main>

      <Footer />
    </>
  );
}
