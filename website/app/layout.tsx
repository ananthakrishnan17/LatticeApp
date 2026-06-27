import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";
import { Analytics } from "@/components/Analytics";
import { ChatWidget } from "@/components/ChatWidget";
import { LanguageProvider } from "@/context/LanguageContext";

const inter = localFont({
  src: "../node_modules/@fontsource-variable/inter/files/inter-latin-wght-normal.woff2",
  variable: "--font-inter",
  display: "swap",
  weight: "100 900",
});

const sora = localFont({
  src: "../node_modules/@fontsource-variable/sora/files/sora-latin-wght-normal.woff2",
  variable: "--font-sora",
  display: "swap",
  weight: "100 800",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://www.nammananban.com"),
  title: "NammaNanban POS | Web & Mobile POS SaaS",
  description:
    "Corporate-premium POS platform for billing, inventory, UPI-ready payments, and GST-ready reporting.",
  alternates: {
    canonical: "/",
  },
  openGraph: {
    title: "NammaNanban POS",
    description:
      "Run your business with a fast, reliable WebPOS and Mobile POS experience.",
    type: "website",
    url: "https://www.nammananban.com",
    images: ["/og-image.svg"],
  },
  twitter: {
    card: "summary_large_image",
    title: "NammaNanban POS",
    description:
      "Run your business with a fast, reliable WebPOS and Mobile POS experience.",
    images: ["/og-image.svg"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className={`${inter.variable} ${sora.variable}`}>
        <LanguageProvider>
          <Analytics />
          {children}
          <ChatWidget />
        </LanguageProvider>
      </body>
    </html>
  );
}
