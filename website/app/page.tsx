import type { Metadata } from "next";
import dynamic from "next/dynamic";
import { CaseStudiesSection } from "@/components/CaseStudiesSection";
import { ContactSection } from "@/components/ContactSection";
import { FeaturesSection } from "@/components/FeaturesSection";
import { Footer } from "@/components/Footer";
import { HeroSection } from "@/components/HeroSection";
import { Navbar } from "@/components/Navbar";
import { VideoExplainerSection } from "@/components/VideoExplainerSection";

const DemoSection = dynamic(() => import("@/components/DemoSection").then((mod) => mod.DemoSection));
const ROICalculator = dynamic(() => import("@/components/ROICalculator").then((mod) => mod.ROICalculator));
const TestimonialsSection = dynamic(() =>
  import("@/components/TestimonialsSection").then((mod) => mod.TestimonialsSection),
);
const FAQSection = dynamic(() => import("@/components/FAQSection").then((mod) => mod.FAQSection));
const PricingSection = dynamic(() => import("@/components/PricingSection").then((mod) => mod.PricingSection));

export const metadata: Metadata = {
  title: "NammaNanban POS - Billing, Inventory & Payments",
  description:
    "Launch faster billing with NammaNanban POS. Offline-ready billing, inventory control, payment tracking, and GST-friendly reports for growing businesses.",
  alternates: {
    canonical: "/",
  },
  openGraph: {
    title: "NammaNanban POS - Billing, Inventory & Payments",
    description:
      "Launch faster billing with NammaNanban POS. Offline-ready billing, inventory control, payment tracking, and GST-friendly reports.",
    images: ["/og-image.svg"],
  },
  twitter: {
    card: "summary_large_image",
    title: "NammaNanban POS - Billing, Inventory & Payments",
    description:
      "Launch faster billing with NammaNanban POS. Offline-ready billing, inventory control, payment tracking, and GST-friendly reports.",
    images: ["/og-image.svg"],
  },
};

export default function Home() {
  return (
    <main>
      <Navbar />
      <HeroSection />
      <VideoExplainerSection />
      <FeaturesSection />
      <DemoSection />
      <ROICalculator />
      <TestimonialsSection />
      <CaseStudiesSection />
      <FAQSection />
      <PricingSection />
      <ContactSection />
      <Footer />
    </main>
  );
}
