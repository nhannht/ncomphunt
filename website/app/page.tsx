import FeatureSections from "@/components/site/FeatureSections";
import Footer from "@/components/site/Footer";
import Gallery from "@/components/site/Gallery";
import Hero from "@/components/site/Hero";
import NavBar from "@/components/site/NavBar";
import OpenSource from "@/components/site/OpenSource";
import SmallFeatures from "@/components/site/SmallFeatures";
import Sources from "@/components/site/Sources";
import Vietnam from "@/components/site/Vietnam";
import { site } from "@/lib/site";

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: site.name,
  description: site.description,
  operatingSystem: "macOS 26.0 or later",
  applicationCategory: "ProductivityApplication",
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
  license: "https://opensource.org/license/mit",
  url: site.url,
  downloadUrl: site.downloadUrl,
  screenshot: `${site.url}/screenshots/as1-hero.png`,
  author: { "@type": "Person", name: site.author, url: site.github },
};

export default function Home() {
  return (
    <>
      <NavBar />
      <main>
        <Hero />
        <FeatureSections />
        <SmallFeatures />
        <Sources />
        <Vietnam />
        <Gallery />
        <OpenSource />
      </main>
      <Footer />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
    </>
  );
}
