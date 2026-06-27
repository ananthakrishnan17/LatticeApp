import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Download NammaNanban Mobile POS APK",
  description:
    "Download the latest NammaNanban Android POS app APK with secure checksum verification and installation instructions.",
  alternates: {
    canonical: "/download",
  },
  openGraph: {
    title: "Download NammaNanban Mobile POS APK",
    description:
      "Get the latest NammaNanban Android POS APK and install in minutes with offline billing support.",
    images: ["/og-image.svg"],
  },
  twitter: {
    card: "summary_large_image",
    title: "Download NammaNanban Mobile POS APK",
    description:
      "Get the latest NammaNanban Android POS APK and install in minutes with offline billing support.",
    images: ["/og-image.svg"],
  },
};

export default function DownloadLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return children;
}
