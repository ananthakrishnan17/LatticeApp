import "./globals.css";
import type { Metadata } from "next";
import { Providers } from "@/components/Providers";
import { Navbar } from "@/components/Navbar";
import { Footer } from "@/components/Footer";

export const metadata: Metadata = {
  title: "Namma Nanban Ecommerce",
  description: "Headless ecommerce storefront for Namma Nanban"
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>
        <Providers>
          <Navbar />
          <main className="container-shell py-8">{children}</main>
          <Footer />
        </Providers>
      </body>
    </html>
  );
}
